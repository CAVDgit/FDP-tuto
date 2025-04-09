# Guide: Migrating Metadata from FairDataPoint 1 to FairDataPoint 2

## Requirements
- Docker Compose v2+
- FairDataPoint v1.16
- GraphDB with a repository named `fdp-store`

---

## Limitations
- FairDataPoint requires a MongoDB database to manage user login information.
- This guide **does not cover** updating the MongoDB database with the new URI structure. That step is **required** for fully migrating users to the new FDP instance.

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

### A. Export Metadata from FairDataPoint 1

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

4. This will download a file: `statements.jsonld`

---

### B. Update URIs in the Backup File

1. Open `statements.jsonld` in a text editor.

2. Replace **all occurrences** of:

```
http://192.168.1.37:8100
```

with:

```
https://ehds.sandbox.com
```

3. Save the modified file as: `new_statements.jsonld`

---

### C. Prepare and Deploy FairDataPoint 2

1. Go to the directory where FDP2 will be deployed (contains `docker-compose.yml` and `application.yaml`).

2. Start only **GraphDB**:
   ```bash
   docker compose up -d graphdb
   ```

3. Access the GraphDB GUI of FDP2:  
   `http://<ip_of_fdp2>:7200`

4. Create a new repository: `fdp-store`

5. Import the updated metadata:
   - Go to **Import > Upload RDF Files**
   - Upload `new_statements.jsonld`
   - Under **Target Graph**, tick the checkbox for **"From Data"**
   - Click **Import**

6. Confirm the import:
   - Go to **Explore > Graphs Overview**
   - Ensure you see URIs starting with:  
     `https://ehds.sandbox.com/dataset/...`

7. Deploy FairDataPoint 2 and other services:
   ```bash
   docker compose up -d
   ```

8. Access FairDataPoint 2:  
   `http://<ip_of_fdp2>:8080` *(adjust if using a different port)*  
   - All metadata records should now use the new URI structure.

---
