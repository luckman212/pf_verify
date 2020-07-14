# pf_verify
Verify pfSense base system files against known-good SHA256 hashes.

## Usage
1. ssh into your target system.

2. choose option 8 (shell).

3. paste in the following command:
```
fetch -q https://raw.githubusercontent.com/luckman212/pf_verify/master/pf_verify.sh
```
4. download a copy of the known-good (reference) checksums for your platform:
```
{TBD}
```
5. run the following command against the file you downloaded in step 4 to verify the integrity of your system:
```
sh pf_verify.sh <checksum_filename>
```
