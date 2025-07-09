# Tdarr Pausarr

Automatically pause a Tdarr container when Jellyfin is playing media.

I prefer to let Tdarr transcode whenever but it can slow down Jellyfin if it's
playing media. This simple script should prevent slowdowns and keep streaming
snappy. I use it to check every 5 seconds and it works well.

## Usage

Environment variables:
- `JELLYFIN_API_KEY`: Your Jellyfin API key (required)
- `JELLYFIN_URL`: The URL of your Jellyfin server (default: http://localhost:8096)
- `TDARR_CONTAINER_NAME`: The name of the Tdarr container (default: tdarr)
- `CHECK_INTERVAL`: How often to check for active streams in seconds (default: 30)

With systemd:

`/etc/systemd/system/tdarr-pausarr.service`
```bash
[Unit]
Description=Jellyfin Tdarr Manager
After=docker.service jellyfin.service
Wants=docker.service

[Service]
Type=simple
User=root
Environment="JELLYFIN_API_KEY=<API_KEY>"
Environment="JELLYFIN_URL=http://localhost:8096"
Environment="TDARR_CONTAINER_NAME=tdarr"
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
sudo systemctl enable tdarr-pausarr
sudo systemctl start tdarr-pausarr
```

## License

Copyright (c) James Plummer <jamesp2001@live.co.uk>

This project is licensed under the MIT license ([LICENSE] or <http://opensource.org/licenses/MIT>)

[LICENSE]: ./LICENSE
