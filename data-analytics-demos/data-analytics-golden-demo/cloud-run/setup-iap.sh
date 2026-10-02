#!/bin/bash
####################################################################################
# Copyright 2026 Google LLC
#
# Helper script to configure Cloud Run Direct Identity-Aware Proxy (IAP)
# for the Rideshare Plus website using Python.
####################################################################################
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
python3 "${SCRIPT_DIR}/setup_iap.py" "$@"
