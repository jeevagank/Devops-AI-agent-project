"""
Aurora Global DB Failover Handler
Triggers a managed failover of the Aurora Global DB from the primary region
(ap-southeast-2, Sydney) to the DR region (ap-southeast-1, Singapore).

Invocation payload (optional):
{
    "global_cluster_identifier": "telstra-aurora-global",   # overrides env var
    "target_db_cluster_identifier": "arn:aws:rds:ap-southeast-1:ACCOUNT:cluster:dr-telstra-aurora"
}

Environment variables:
    GLOBAL_CLUSTER_IDENTIFIER       - Aurora Global DB identifier
    TARGET_DB_CLUSTER_ARN           - ARN of the DR secondary cluster in Singapore
    SNS_TOPIC_ARN                   - SNS topic to publish failover notifications
"""

import json
import logging
import os
import time

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

PRIMARY_REGION = "ap-southeast-2"
DR_REGION      = "ap-southeast-1"


def handler(event, context):
    global_cluster_id  = event.get("global_cluster_identifier") or os.environ["GLOBAL_CLUSTER_IDENTIFIER"]
    target_cluster_arn = event.get("target_db_cluster_identifier") or os.environ["TARGET_DB_CLUSTER_ARN"]
    sns_topic_arn      = os.environ.get("SNS_TOPIC_ARN")

    logger.info("Starting Aurora Global DB failover")
    logger.info("Global cluster : %s", global_cluster_id)
    logger.info("Target cluster : %s", target_cluster_arn)

    rds_primary = boto3.client("rds", region_name=PRIMARY_REGION)
    rds_dr      = boto3.client("rds", region_name=DR_REGION)

    # ── 1. Validate current global cluster state ───────────────────────────────
    try:
        global_cluster = _describe_global_cluster(rds_primary, global_cluster_id)
    except ClientError as e:
        logger.error("Failed to describe global cluster: %s", e)
        raise

    primary_member = _get_primary_member(global_cluster)
    if not primary_member:
        raise RuntimeError("Could not identify primary cluster member in global cluster.")

    logger.info("Current primary: %s", primary_member["DBClusterArn"])

    if primary_member["DBClusterArn"] == target_cluster_arn:
        logger.warning("Target cluster is already the primary. No failover needed.")
        return _response(200, "Target is already primary — no action taken.")

    # ── 2. Trigger managed failover ────────────────────────────────────────────
    logger.info("Initiating failover to %s ...", target_cluster_arn)
    try:
        rds_primary.failover_global_cluster(
            GlobalClusterIdentifier=global_cluster_id,
            TargetDbClusterIdentifier=target_cluster_arn,
        )
    except ClientError as e:
        logger.error("failover_global_cluster failed: %s", e)
        _notify(sns_topic_arn, "FAILOVER_FAILED", global_cluster_id, str(e))
        raise

    # ── 3. Poll until failover completes ──────────────────────────────────────
    logger.info("Polling for failover completion ...")
    _wait_for_failover(rds_dr, global_cluster_id, target_cluster_arn)

    # ── 4. Verify new primary ──────────────────────────────────────────────────
    updated_cluster = _describe_global_cluster(rds_dr, global_cluster_id)
    new_primary     = _get_primary_member(updated_cluster)

    if new_primary and new_primary["DBClusterArn"] == target_cluster_arn:
        logger.info("Failover successful. New primary: %s", new_primary["DBClusterArn"])
        _notify(sns_topic_arn, "FAILOVER_SUCCESS", global_cluster_id,
                f"New primary: {new_primary['DBClusterArn']}")
        return _response(200, "Failover completed successfully.", new_primary["DBClusterArn"])

    raise RuntimeError(f"Failover completed but new primary is unexpected: {new_primary}")


# ── Helpers ────────────────────────────────────────────────────────────────────

def _describe_global_cluster(rds_client, global_cluster_id):
    resp = rds_client.describe_global_clusters(
        GlobalClusterIdentifier=global_cluster_id
    )
    clusters = resp.get("GlobalClusters", [])
    if not clusters:
        raise RuntimeError(f"Global cluster '{global_cluster_id}' not found.")
    return clusters[0]


def _get_primary_member(global_cluster):
    for member in global_cluster.get("GlobalClusterMembers", []):
        if member.get("IsWriter"):
            return member
    return None


def _wait_for_failover(rds_client, global_cluster_id, target_cluster_arn,
                       max_wait_seconds=600, poll_interval=15):
    elapsed = 0
    while elapsed < max_wait_seconds:
        time.sleep(poll_interval)
        elapsed += poll_interval

        try:
            cluster = _describe_global_cluster(rds_client, global_cluster_id)
        except ClientError:
            logger.warning("Transient error describing cluster during poll — retrying ...")
            continue

        primary = _get_primary_member(cluster)
        status  = cluster.get("Status", "")

        logger.info("Status: %s | Primary: %s | Elapsed: %ds",
                    status, primary.get("DBClusterArn") if primary else "unknown", elapsed)

        if primary and primary["DBClusterArn"] == target_cluster_arn:
            return

    raise TimeoutError(
        f"Failover did not complete within {max_wait_seconds}s. "
        "Check RDS console for current state."
    )


def _notify(sns_topic_arn, event_type, global_cluster_id, detail):
    if not sns_topic_arn:
        return
    sns = boto3.client("sns", region_name=DR_REGION)
    message = {
        "event":                  event_type,
        "global_cluster":         global_cluster_id,
        "primary_region_before":  PRIMARY_REGION,
        "dr_region":              DR_REGION,
        "detail":                 detail,
    }
    try:
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f"Aurora Global DB Failover — {event_type}",
            Message=json.dumps(message, indent=2),
        )
        logger.info("SNS notification sent: %s", event_type)
    except ClientError as e:
        logger.warning("Failed to send SNS notification: %s", e)


def _response(status_code, message, new_primary_arn=None):
    body = {"message": message}
    if new_primary_arn:
        body["new_primary_arn"] = new_primary_arn
    return {"statusCode": status_code, "body": json.dumps(body)}
