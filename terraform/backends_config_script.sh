#!/bin/bash

touch backend.tf
rm -r backend.tf
echo 'terraform {
backend "gcs" {
bucket = "argolis-click-to-deploy"
prefix = "'$1'/'$2'/Sample_Demo_state"
}
}' >> backend.tf