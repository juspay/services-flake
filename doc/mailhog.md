# Mailhog

[Mailhog SMTP server](https://grafana.com/docs/loki/latest/) is Web and API based SMTP testing tool.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.mailhog."mh".enable = true;
}
```

{#tips}

## Tips & Tricks

### Send Emails

```bash
message="$(printf 'From: sender@example.com\r\nTo: recipient@example.com\r\nSubject: Test email\r\n\r\nThis is a test message sent via curl to MailHog.\r\n')"

echo "Sending email."
curl -sS smtp://127.0.0.1:1025 \
        --mail-from "sender@example.com" \
        --mail-rcpt "recipient@example.com" \
        --upload-file - <<< "$message"
```

### Web UI

Inspect [https://localhost:8025](https://localhost:8025).

### Using the API

```bash
curl http://127.0.0.1:8025/api/v2/messages | jq
```
