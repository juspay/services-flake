# Mailhog

[Mailhog SMTP server](https://github.com/mailhog/MailHog) is a Web and API based SMTP testing tool
which only runs in RAM and has not storage.

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

Inspect [http://localhost:8025](https://localhost:8025).

### Using the API

```bash
curl http://127.0.0.1:8025/api/v2/messages | jq
```
