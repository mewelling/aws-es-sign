#! /bin/bash

# Set script variables from .env conf file
set -a
source .env
set +a

# Configure defaults
TEMP_DIR="${TEMP_DIR:-/tmp}"
ES_SERVICE="${ES_SERVICE:-es}"
ES_METHOD="${ES_METHOD:-GET}"

# Parse and compact the JSON payload
PAYLOAD=$TEMP_DIR/payload.json
jq -j -c . < $JSON_PAYLOAD_PATH > $PAYLOAD

CONTENT_SHA=`openssl dgst -sha256 $PAYLOAD | cut -d' ' -f 2`
CONTENT_LENGTH=`wc -c $PAYLOAD | awk '{print $1}'`
DATE=`date -u +"%Y%m%dT%H%M%SZ"`
SHORT_DATE=`echo $DATE | cut -d'T' -f 1`

# Step 1: Canonical request
echo -n $"$ES_METHOD
$ELASTIC_ENDPOINT

content-length:$CONTENT_LENGTH
content-type:application/json
host:$ELASTIC_HOST
x-amz-content-sha256:$CONTENT_SHA
x-amz-date:$DATE

content-length;content-type;host;x-amz-content-sha256;x-amz-date
$CONTENT_SHA" > $TEMP_DIR/signature.creq

# Step 2: String to sign
echo -n $"AWS4-HMAC-SHA256
$DATE
$SHORT_DATE/$AWS_REGION/$ES_SERVICE/aws4_request
`openssl dgst -sha256 $TEMP_DIR/signature.creq | cut -d' ' -f 2`" > $TEMP_DIR/stringtosign.sts

# Step 3: Generate user’s signing key
function hmac_sha256 {
  key="$1"
  data="$2"
  echo -n "$data" | openssl dgst -sha256 -mac HMAC -macopt "$key" | sed 's/^.* //'
}

# Four-step signing key calculation
dateKey=$(hmac_sha256 key:"AWS4$AWS_SECRET_KEY" $SHORT_DATE)
dateRegionKey=$(hmac_sha256 hexkey:$dateKey $AWS_REGION)
dateRegionServiceKey=$(hmac_sha256 hexkey:$dateRegionKey $ES_SERVICE)
signingKey=$(hmac_sha256 hexkey:$dateRegionServiceKey "aws4_request")

# Step 4: Calculate signature
signature=`openssl dgst -sha256 \
             -mac HMAC \
             -macopt hexkey:$signingKey \
             $TEMP_DIR/stringtosign.sts | cut -d' ' -f 2`

# Step 5: Build and send the “Authorization” header
curl --header "Authorization: AWS4-HMAC-SHA256 \
               Credential=$AWS_ACCESS_KEY_ID/$SHORT_DATE/$AWS_REGION/$ES_SERVICE/aws4_request, \
               SignedHeaders=content-length;content-type;host;x-amz-content-sha256;x-amz-date, \
               Signature=$signature" \
     --header "x-amz-content-sha256: $CONTENT_SHA" \
     --header "x-amz-date: $DATE" \
     --header "Content-Type: application/json" \
     --header "Content-Length: $CONTENT_LENGTH" \
     --data "@$PAYLOAD" \
     -v -X $ES_METHOD https://$ELASTIC_HOST/$ELASTIC_ENDPOINT
