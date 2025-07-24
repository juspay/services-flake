# Plantuml

[Plantuml](https://plantuml.com/) is a tool that allows users to create diagrams from plain text descriptions. It supports various diagram types, including sequence diagrams, use case diagrams, class diagrams, activity diagrams, component diagrams, state diagrams, and more.

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.plantuml."instance-name" = {
    enable = true;
    port = 1234;
    host = "127.0.0.1";
  };
}
```
