🪶 InsightKit

Capture • Understand • Report

InsightKit is a modern Swift framework for unified logging and diagnostics.
It provides a lightweight, thread-safe way to log messages to disk and console, automatically rotate large files, and archive diagnostic bundles for review or support.

⸻

✨ Features
	•	Structured file + console logging
	•	Thread-safe write queue
	•	Automatic log rotation
	•	ZIP archive creation for reports
	•	Optional short log extraction for summaries
	•	macOS diagnostics (system and running apps info)
	•	Works out of the box — no configuration needed

⸻

🧩 Example

import InsightKit

let log = InsightCenter.shared

log.info("Application launched.")
log.warning("Low memory warning.")
log.error("Unexpected nil value in response.")

Create a ZIP bundle for sharing or analysis

if let archiveURL = log.makeArchive() {
    print("Log archive created at: \(archiveURL.path)")
}


⸻

📁 Default Storage

Platform	Location
macOS	~/Library/Logs/InsightKit/insight.log
iOS / Others	Temporary directory (/tmp/InsightKit/insight.log)

Rotated files are stored in the same directory using timestamped filenames.

⸻

⚙️ Integration

Swift Package Manager

Add InsightKit to your project in Xcode:

https://github.com/yourusername/InsightKit

Or include it in Package.swift:

.package(url: "https://github.com/yourusername/InsightKit.git", from: "1.0.0")


⸻

🧾 License

MIT License

© 2025 Michel Storms
Free for personal and commercial use with attribution.

⸻

💬 Philosophy

“Insight before complexity.”

InsightKit is designed for developers who want powerful diagnostics with minimal setup.
Just import, log, and focus on building — the insights will follow.
