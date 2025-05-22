# 🪵 cwlogs - AWS CloudWatch Log Viewer for Terminal

[![Release](https://github.com/HarveyGG/aws-cloudwatch-viewer-cli/actions/workflows/release.yml/badge.svg)](https://github.com/HarveyGG/aws-cloudwatch-viewer-cli/actions)

> A powerful CLI to filter, highlight, and visualize AWS CloudWatch Logs with HTML output.

---

## 🚀 Features

- 🔍 Regex filtering for log stream names
- 🟡 Keyword highlighting with `<mark>` tags
- 🕒 Time range control: `--range=5m`, `30m`, `1h`
- 📄 HTML report generation (opened in browser)
- 🧹 Auto-delete temp files or `--keep` to retain
- 📦 Homebrew support: `brew install cwlogs`

---

## 🛠 Installation

```bash
brew tap HarveyGG/cwlogs
brew install cwlogs
```

### Upgrade to latest:
```
brew update
brew upgrade cwlogs
```

## 💻 Usage
```
cwlogs <alias> [keyword] [--range=5m|30m|1h] [--keep]
```
### Examples
```
cwlogs delivery20 error --range=5m
cwlogs dispatch-job "Exception|Timeout" --keep
```

## 🔬 Development
To test locally:
```
./bin/cwlogs_real.sh delivery15 "500|timeout" --range=30m --keep
```

## 🧪 GitHub Actions Automation
* Push a new tag: v1.0.1
* GitHub Actions will:
	* Generate .tar.gz
	* Compute SHA256
	* Push Formula/cwlogs.rb to homebrew-cwlogs