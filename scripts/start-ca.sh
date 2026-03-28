#!/bin/bash
export STEPPATH="$(dirname "$0")/../ca"
step-ca "$STEPPATH/config/ca.json"
