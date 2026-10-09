# Glance start page at https://trench.tail4a3e06.ts.net (tailnet only).
{
  selfhost.dashboard = {
    enable = true;

    # Apps that aren't Nix-hosted, so selfhost.expose doesn't know them.
    extraSites = [
      {
        title = "orchard";
        url = "https://orchard.matm.icu";
        icon = "si:kubernetes";
      }
    ];

    links = [

      {
        title = "dots repo";
        url = "https://github.com/matmanna/dots";
      }
      {
        title = "cloudflare dns";
        url = "https://dash.cloudflare.com";
      }
      {
        title = "contabo panel";
        url = "https://my.contabo.com";
      }
    ];
  };
}
