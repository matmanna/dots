# home.matm.icu: Glance start page, login required.
{ config, ... }:
{
  age.secrets."glance/secret-key".file = ../../secrets/glance/secret-key.age;
  age.secrets."glance/password-hash".file = ../../secrets/glance/password-hash.age;

  selfhost.dashboard = {
    enable = true;
    domain = "home.matm.icu";
    user = "matmanna";
    secretKeyFile = config.age.secrets."glance/secret-key".path;
    passwordHashFile = config.age.secrets."glance/password-hash".path;

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
