# dump-ipa.sh

This simple script uses SSH to connect to a jailbroken iOS device and [appdecrypt](https://github.com/paradiseduo/appdecrypt) to dump and download a decrypted IPA of any app from that device.

```
Usage: ./dump-ipa.sh [-h] [-H <ip>] [-u <user>] [-o <output_directory>] <app_name>
Options:
  -h      Show this help message and exit
  -H      IP address of the remote device
  -u      Username of the remote device
  -o      Output directory (default: ~/Downloads)
Note: -H (IP address) and -u (username) options are required if .env file is not present.
```

## Requirements

- [appdecrypt](https://github.com/paradiseduo/appdecrypt) iOS binary. The script currently expects this file to be in `~/appdecrypt/appdecrypt`, but you can modify this to your preference.

- `plutil` installed on the jailbroken device.

## Get started

1. Create a `.env` file in the same directory as the script with the following values:

```bash
ip=#<your_ip_addr>
user=#<your_username>
```

> [!NOTE]
> If you prefer not to create an `.env` file, you can provide the values as arguments when running the script. I recommend creating one tho so you don't have to type in the same stuff in every time.

2. Then, run the script passing in the app's name (case-insensitive), so something like:

```bash
./dump-ipa.sh youtube
```

3. You will have to authenticate for SSH 3 times (1 to send `appdecrypt`, 1 to find and decrypt the app, and 1 to download it) which is not ideal but I haven't been able to come up with a better solution yet.

4. If all goes well, your decrypted IPA file will land in `~/Downloads`.

## Known issues
- Download sometimes fails with error `client_loop: send disconnect: Broken pipe`.
- Finding and decrypting step takes forever sometimes.

## License
[The MIT License](LICENSE)
