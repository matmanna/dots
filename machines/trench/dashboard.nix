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

    sideWidgets = [
      {
        type = "group";
        widgets =
          map
            (w: {
              type = "weather";
              inherit (w) title location;
              units = "imperial";
              hour-format = "12h";
            })
            [
              {
                title = "state college";
                location = "State College, Pennsylvania, United States";
              }
              {
                title = "harrisburg";
                location = "Harrisburg, Pennsylvania, United States";
              }
              {
                title = "san francisco";
                location = "San Francisco, California, United States";
              }
            ];
      }
    ];

    extraWidgets = [
      {
        type = "hacker-news";
        limit = 15;
        collapse-after = 5;
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
