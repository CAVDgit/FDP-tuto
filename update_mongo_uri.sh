#!/bin/bash

# --- CONFIGURATION ---

CONTAINER_NAME="mongo"       # Docker container name
DB_NAME="fdp"                # MongoDB database name
COLLECTION_METADATA="metadata"
COLLECTION_ACL="ACL"

USERNAME=""                  # Leave empty to skip auth
PASSWORD=""                  # Leave empty to skip auth
AUTH_DB="admin"

OLD_URI="http://192.168.1.37:8100"
NEW_URI="https://ehds.sandbox.com:443"

# -----------------------

# Build authentication options
AUTH_OPTS=""
if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
  AUTH_OPTS="-u $USERNAME -p $PASSWORD --authenticationDatabase $AUTH_DB"
fi

echo "🔍 Detecting MongoDB version in container: $CONTAINER_NAME..."

# Get the MongoDB version string
VERSION_OUTPUT=$(docker exec -i "$CONTAINER_NAME" mongo $AUTH_OPTS --quiet --eval "db.version()" 2>/dev/null)
VERSION_CLEAN=$(echo "$VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+')

if [[ -z "$VERSION_CLEAN" ]]; then
  echo "❌ Could not detect MongoDB version or authentication failed."
  exit 1
fi

echo "✅ Detected MongoDB version: $VERSION_CLEAN"

# Function to compare versions (returns 0 if >= required)
version_compare() {
  awk -v v1="$1" -v v2="$2" 'BEGIN {
    split(v1,a,"."); split(v2,b,".");
    for(i=1;i<=2;i++) {
      if (a[i] < b[i]) exit 1;
      if (a[i] > b[i]) exit 0;
    }
    exit 0;
  }'
}

# Prepare update commands
if version_compare "$VERSION_CLEAN" "4.2"; then
  echo "📦 Using aggregation pipeline updates"

  UPDATE_CMD="
db.getCollection('$COLLECTION_METADATA').updateMany(
  { uri: { \$regex: '^$OLD_URI' } },
  [
    {
      \$set: {
        uri: {
          \$replaceOne: {
            input: '\$uri',
            find: '$OLD_URI',
            replacement: '$NEW_URI'
          }
        }
      }
    }
  ]
);
db.getCollection('$COLLECTION_ACL').updateMany(
  { instanceId: { \$regex: '^$OLD_URI' } },
  [
    {
      \$set: {
        instanceId: {
          \$replaceOne: {
            input: '\$instanceId',
            find: '$OLD_URI',
            replacement: '$NEW_URI'
          }
        }
      }
    }
  ]
);"

else
  echo "🧱 Using classic updates with replaceOne"

  UPDATE_CMD="
db.getCollection('$COLLECTION_METADATA').find({ uri: { \$regex: '^$OLD_URI' } }).forEach(function(doc) {
  doc.uri = doc.uri.replace('$OLD_URI', '$NEW_URI');
  db.getCollection('$COLLECTION_METADATA').replaceOne({ _id: doc._id }, doc);
});
db.getCollection('$COLLECTION_ACL').find({ instanceId: { \$regex: '^$OLD_URI' } }).forEach(function(doc) {
  doc.instanceId = doc.instanceId.replace('$OLD_URI', '$NEW_URI');
  db.getCollection('$COLLECTION_ACL').replaceOne({ _id: doc._id }, doc);
});"
fi

# Run both updates together
echo "🚀 Running MongoDB updates in both collections..."
docker exec -i "$CONTAINER_NAME" mongo "$DB_NAME" $AUTH_OPTS --quiet --eval "$UPDATE_CMD"

# ✅ Final message
echo "✅ All updates completed successfully!"
