Storage Auction Game (working title) - test build

1. Unzip this folder anywhere.
2. Double-click StorageAuctionGame.exe.
3. Windows may say "Windows protected your PC" because test builds are not
   signed. Click "More info", then "Run anyway".

Mouse, keyboard and gamepad all work. Saves go to
%APPDATA%\Godot\app_userdata\Storage Auction Game\saves

PLAY WITH FRIENDS (2 to 4 players)

Everyone needs this same build.

1. One person hosts: "Play with friends", type a name, "Host a game".
   The screen shows the address friends type in.
2. Everyone else: "Play with friends", type a name, type the host's
   address, "Join".
3. When everyone's in the crew list, the host presses "Start a new game"
   (or "Carry on the saved game").

On the same home network, that's all. Over the internet, either:
- the host forwards UDP port 47100 on their router to their PC, and friends
  join with the host's public IP address (search "what is my IP"); or
- everyone installs Tailscale (free, tailscale.com), signs in to the same
  network, and friends join with the host's Tailscale address (100.x.x.x).
If Windows asks whether to let the game use the network, allow it.

Steam invites replace all of this once the game is on Steam.
