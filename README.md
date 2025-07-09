# Pausarr

Automatically pause containers when Jellyfin has an active session.

I prefer to let Tdarr transcode whenever but it can slow down Jellyfin if
someone is using it. This simple script should prevent slowdowns and keep
Jellyfin snappy. I use it to check every 5 seconds and it works well.

Originally written for Tdarr but can be now be used with multiple containers.

## Usage

Environment variables:
- `JELLYFIN_API_KEY`: Your Jellyfin API key (required)
- `JELLYFIN_URL`: The URL of your Jellyfin server (default: http://localhost:8096)
- `CONTAINERS_TO_PAUSE`: Comma separated list of containers to pause (default: tdarr,sonarr)
- `CHECK_INTERVAL`: How often to check for active streams in seconds (default: 30)

With systemd:

`/etc/systemd/system/pausarr.service`
```bash
[Unit]
Description=Pausarr
After=docker.service jellyfin.service
Wants=docker.service

[Service]
Type=simple
User=root
Environment="JELLYFIN_API_KEY=<API_KEY>"
Environment="JELLYFIN_URL=http://localhost:8096"
Environment="CONTAINERS_TO_PAUSE=tdarr,sonarr"
Environment="CHECK_INTERVAL=30"
ExecStart=<PATH_TO_SCRIPT>
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable pausarr
sudo systemctl start pausarr
```

## License

Copyright (c) James Plummer <jamesp2001@live.co.uk>

This project is licensed under the MIT license ([LICENSE] or <http://opensource.org/licenses/MIT>)

[LICENSE]: ./LICENSE
