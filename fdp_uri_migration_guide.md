
# How to migrate metadata from one FDP instance to another (e.g., changing base URIs)

## Requirements
- Docker Compose v2+
- FairDataPoint v1.16
- MongoDB v4
- GraphDB with a repository named `fdp-store`

---

## Initial Setup

### FairDataPoint 1

Running with the following `application.yaml`:

```yaml
instance:
  clientUrl: http://192.168.1.37:8100 # Current URI structure
```

### FairDataPoint 2

Not yet deployed. Planned `application.yaml`:

```yaml
instance:
  clientUrl: https://ehds.sandbox.com # New desired URI structure
```

---

## Migration Steps

### A. Export RDF Metadata from FairDataPoint 1

1. Access the **GraphDB GUI** of FDP1:  
   `http://<ip_of_fdp1>:7200`

2. Go to **Explore > Graphs Overview**  
   - Look for metadata graphs starting with:  
     `http://192.168.1.37:8100/dataset/...`

3. Export all metadata:
   - Go to **Export > Export Repository**
   - Choose format: **JSON-LD**
   - Select option: **`..#expanded`**
   - ⚠️ *Do not use Turtle format — it does not preserve the full graph structure*
   - This will download a file: `statements.jsonld`

4. Export the MongoDB database:
   - In the root folder where FairDataPoint 1 is deployed (where the MongoDB volume is defined in `docker-compose.yml`), locate the `/mongo` folder.
   - Copy this folder to the future deployment directory of FairDataPoint 2.

---

### B. Update URIs in the RDF Backup

1. Open `statements.jsonld` in a text editor.

2. Replace **all occurrences** of:

```
http://192.168.1.37:8100
```

with:

```
https://ehds.sandbox.com
```

3. Save the modified file as `new_statements.jsonld`.

---

### C. Update URIs in the MongoDB Metadata

1. Go to the root folder of FairDataPoint 2 (where the new MongoDB container will be deployed).

2. Start the MongoDB container:
   ```bash
   docker compose up -d mongo
   ```

3. Create a new script file:
   ```bash
   nano migrate_mongo_uri.sh
   ```

4. Paste the migration script (see in this github) and update the configuration section:

```bash
OLD_URI="http://192.168.1.37:8100"
NEW_URI="https://ehds.sandbox.com"
```

5. Make it executable:
   ```bash
   chmod +x migrate_mongo_uri.sh
   ```

6. Execute the script to update all `uri` values in the metadata collection:
   ```bash
   ./migrate_mongo_uri.sh
   ```

7. All URIs in MongoDB should now be updated to reflect the new FDP base URI.

---

### D. Upload Updated RDF Metadata to the New GraphDB

1. Go to the directory where FDP2 will be deployed (contains `docker-compose.yml` and `application.yaml`).

2. Start only **GraphDB**:
   ```bash
   docker compose up -d graphdb
   ```

3. Access the GraphDB GUI for FDP2:  
   `http://<ip_of_fdp2>:7200`

4. Create a new repository: `fdp-store`

5. Import the updated RDF metadata:
   - Go to **Import > Upload RDF Files**
   - Upload `new_statements.jsonld`
   - Under **Target Graph**, tick the checkbox for **"From Data"**
   - Click **Import**

6. Confirm the import:
   - Go to **Explore > Graphs Overview**
   - Ensure you see URIs starting with:  
     `https://ehds.sandbox.com/dataset/...`

---

### E. Deploy FairDataPoint 2 Server and Client

1. Deploy FairDataPoint 2 and all related services:
   ```bash
   docker compose up -d
   ```

2. Access FairDataPoint 2:  
   `http://<ip_of_fdp2>:8080` *(adjust if using a different port)*

3. All metadata records should now reflect the new URI structure, and previously associated user data should be preserved.

---
