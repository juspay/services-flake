{ pkgs, ... }:
{
  services.mailhog."mh".enable = true;

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
      ];

      text = ''
        message="$(printf 'From: sender@example.com\r\nTo: recipient@example.com\r\nSubject: Test email\r\n\r\nThis is a test message sent via curl to MailHog.\r\n')"

        echo "Sending email."
        curl -sS smtp://127.0.0.1:1025 \
          --mail-from "sender@example.com" \
          --mail-rcpt "recipient@example.com" \
          --upload-file - <<< "$message"

        echo "Send exit code: $?"

        echo "Getting message."
        curl http://127.0.0.1:8025/api/v2/messages | jq -e '.items[] | select(.Content.Headers.Subject[0] == "Test email")'
      '';
      name = "mailhog-test";
    };

    depends_on."mh".condition = "process_healthy";
  };
}
