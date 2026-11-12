# Web Dashboard & Charts

The ThingLarp Web Dashboard at **[https://thinglarp.iimarky123.io.vn/app/](https://thinglarp.iimarky123.io.vn/app/)** provides real-time visualizations and channel management directly in your browser.

---

## Live Telemetry Streaming

When you open a channel:
- The dashboard automatically opens a secure WebSocket stream (`wss://mqtt.iimarky123.io.vn/mqtt`) with QoS 1.
- The top status bar indicates:
  - **Streaming Live Data (QoS 1)**: Real-time sensor updates push directly to the chart.
  - **Pause / Resume**: You can pause the live stream to inspect a specific historical snapshot.

---

## Field Widgets & Visualizations

Every auto-discovered field gets a metric card displaying its latest value, unit, and time-series line chart.

### Customizing Widget Types
Owners can customize how each metric is rendered by clicking the **Tune** icon (`⋮`) on any field card:

| Widget Type | Best For | Visual Representation |
| :--- | :--- | :--- |
| **Line Chart** *(default)* | Continuous time-series | Interactive line chart with min/max/average markers |
| **Gauge** | Percentage or bounded ranges (0–100%) | Radial dial with warning thresholds |
| **Bar Chart** | Discrete readings, counts, energy consumption | Categorical vertical bars |
| **Status Card / KPI** | On/off states, alarms, counters | Large bold display with live trend indicator |

### Adjusting Query Resolution
The dashboard features an automatic rollup selector:
- **Auto Resolution**: Automatically chooses the ideal rollup (raw, 1-minute, or 1-hour) based on data volume.
- **Raw Points**: Displays exact microsecond data points.
- **1-min Averages**: Continuous rollup averages calculated every 60 seconds.
- **1-hour Averages**: Ideal for viewing multi-week or multi-month historical trends.

---

## Exporting & Importing Data

From the channel menu (`⋮` in the top right of the channel screen):

### 1. Download / Export Data
- Export all historical telemetry as standard **CSV** format.
- Select date range and limit (up to 10,000 points per export).
- Ideal for analysis in Python (pandas), Excel, MATLAB, or Jupyter notebooks.

### 2. Import CSV Data
- Bulk-upload historical CSV data into your channel.
- Automatically handles ISO-8601 timestamps and key-value mapping.

### 3. Clear Telemetry Data
- Clears all collected historical points for the channel while preserving provisioned devices and field customizations.
