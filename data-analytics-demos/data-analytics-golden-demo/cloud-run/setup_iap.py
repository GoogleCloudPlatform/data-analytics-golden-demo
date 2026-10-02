#!/usr/bin/env python3
"""
Setup and configure Cloud Run Direct Identity-Aware Proxy (IAP) for the Rideshare Plus website.
This script ensures:
1. The IAP API and IAP Service Identity are enabled/created.
2. The IAP Service Agent is granted 'roles/run.invoker' on the Cloud Run service.
3. Unauthenticated/anonymous 'allUsers' access is revoked.
4. Direct IAP is enabled on the Cloud Run service via 'gcloud run services update --iap'.
5. The deploying GCP user is granted 'roles/iap.httpsResourceAccessor' as the sole accessor.
"""

import argparse
import subprocess
import sys


def run_cmd(cmd: list[str], check: bool = True, capture_output: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the completed process."""
    print(f"Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, check=False, text=True, capture_output=capture_output)
    if res.returncode != 0:
        if check:
            print(f"Error running command: {' '.join(cmd)}", file=sys.stderr)
            if res.stderr:
                print(f"Stderr: {res.stderr.strip()}", file=sys.stderr)
            if res.stdout:
                print(f"Stdout: {res.stdout.strip()}", file=sys.stderr)
            sys.exit(res.returncode)
    return res


def get_gcloud_config_value(param: str) -> str:
    """Read a property value from gcloud config."""
    res = run_cmd(["gcloud", "config", "get-value", param, "--format=value(core)"], check=False)
    val = res.stdout.strip()
    return val if val != "(unset)" else ""


def main():
    parser = argparse.ArgumentParser(description="Configure Direct IAP on Rideshare Plus Cloud Run website.")
    parser.add_argument("--project-id", required=False, help="Google Cloud Project ID")
    parser.add_argument("--region", required=False, help="Cloud Run region (e.g. us-central1)")
    parser.add_argument("--service-name", default="demo-rideshare-plus-website", help="Cloud Run service name")
    parser.add_argument("--gcp-account-name", required=False, help="User email to grant IAP access to")
    args = parser.parse_args()

    # Determine Project ID
    project_id = args.project_id or get_gcloud_config_value("project")
    if not project_id:
        print("Error: --project-id not provided and could not be determined from gcloud config.", file=sys.stderr)
        sys.exit(1)

    # Determine Region
    region = args.region or get_gcloud_config_value("run/region") or "us-central1"

    # Determine GCP Account Name
    gcp_account_name = args.gcp_account_name or get_gcloud_config_value("account")
    if not gcp_account_name:
        print("Error: --gcp-account-name not provided and could not be determined from gcloud config.", file=sys.stderr)
        sys.exit(1)

    service_name = args.service_name

    print("=" * 60)
    print("Securing Rideshare Plus Website with Identity-Aware Proxy (IAP)")
    print(f"  Project ID:        {project_id}")
    print(f"  Region:            {region}")
    print(f"  Service Name:      {service_name}")
    print(f"  Authorized User:   {gcp_account_name}")
    print("=" * 60)

    # 1. Enable IAP API
    print("\n[1/6] Enabling iap.googleapis.com...")
    run_cmd(["gcloud", "services", "enable", "iap.googleapis.com", f"--project={project_id}"])

    # 2. Ensure IAP Service Identity exists
    print("\n[2/6] Ensuring IAP Service Identity exists...")
    run_cmd(["gcloud", "services", "identity", "create", "--service=iap.googleapis.com", f"--project={project_id}"], check=False)

    # 3. Retrieve Project Number for IAP Service Account
    print("\n[3/6] Retrieving project number for IAP Service Agent...")
    res_num = run_cmd(["gcloud", "projects", "describe", project_id, "--format=value(projectNumber)"])
    project_number = res_num.stdout.strip()
    if not project_number:
        print("Error: Could not retrieve project number.", file=sys.stderr)
        sys.exit(1)
    iap_sa = f"serviceAccount:service-{project_number}@gcp-sa-iap.iam.gserviceaccount.com"
    print(f"  IAP Service Agent: {iap_sa}")

    # Grant roles/run.invoker to IAP Service Agent
    print(f"\n[4/6] Granting roles/run.invoker to {iap_sa}...")
    run_cmd([
        "gcloud", "run", "services", "add-iam-policy-binding", service_name,
        f"--project={project_id}",
        f"--region={region}",
        f"--member={iap_sa}",
        "--role=roles/run.invoker"
    ])

    # Revoke allUsers access if present
    print("\n[4b/6] Removing unauthenticated allUsers invoker access if present...")
    run_cmd([
        "gcloud", "run", "services", "remove-iam-policy-binding", service_name,
        f"--project={project_id}",
        f"--region={region}",
        "--member=allUsers",
        "--role=roles/run.invoker"
    ], check=False)

    # 5. Enable Direct IAP on the Cloud Run service
    print("\n[5/6] Enabling Direct IAP on Cloud Run service...")
    run_cmd([
        "gcloud", "run", "services", "update", service_name,
        f"--project={project_id}",
        f"--region={region}",
        "--iap"
    ])

    # 6. Grant IAP-secured Web App User to deploying user
    print(f"\n[6/6] Granting roles/iap.httpsResourceAccessor to user:{gcp_account_name}...")
    run_cmd([
        "gcloud", "iap", "web", "add-iam-policy-binding",
        f"--project={project_id}",
        "--resource-type=cloud-run",
        f"--service={service_name}",
        f"--region={region}",
        f"--member=user:{gcp_account_name}",
        "--role=roles/iap.httpsResourceAccessor"
    ])

    # Display Service URL and confirmation
    res_url = run_cmd([
        "gcloud", "run", "services", "describe", service_name,
        f"--project={project_id}",
        f"--region={region}",
        "--format=value(status.url)"
    ], check=False)
    service_url = res_url.stdout.strip()

    print("\n" + "=" * 60)
    print("Cloud Run Direct IAP Configuration Complete!")
    if service_url:
        print(f"  Service URL:      {service_url}")
    print(f"  Secured By:       Identity-Aware Proxy (IAP)")
    print(f"  Authorized User:  user:{gcp_account_name}")
    print("=" * 60)


if __name__ == "__main__":
    main()
