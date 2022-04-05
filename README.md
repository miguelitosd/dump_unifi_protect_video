# dump_unifi_protect_video

Quick and dirty perl wrapper I wrote to walk the drive from a UniFi-Protect install and convert all the (non-timelapse) ubv files into mp4 files, saved in a Year/Month/Day/Camera directory structure

## Requirements
* You must have the remux command (and it's requirements) installed and in your $PATH, see: https://github.com/petergeneric/unifi-protect-remux
* Note that I found the ubnt_ubvinfo binary from my UDM-PRO by:
    * ssh into the udm-pro
    * run: unifi-os shell
    * scp /usr/share/unifi-protect/app/node_modules/.bin/ubnt_ubvinfo $another_host:/tmp

## Info on run and examples
I converted all the files from my ~7T disk out of my UDM-PRO (moved to a UNVR) in just under 30 hours.

I ran it as:
```
~/dump_unifi_protect_video/dump_unifi_protect.pl --verbose --debug --cameras ~/unifi-protect-udmpro-backup/cameras.json --input /mnt/ubnt-protect-in/unifi-os/unifi-protect/video --output /mnt/ubnt-protect-out
```

Sample end of the output from the script:
```
run_cmd: remux -with-audio /mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2022/04/02/FCECDA30AF6E_0_rotating_1648928108633.ubv
Move FCECDA30AF6E_0_rotating_2022-04-02T12.34.58-07.00.mp4, /mnt/ubnt-protect-out/video/2022/04/02/Interior DomeCam/12.34.58-07.00.mp4
run_cmd: remux -with-audio /mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2022/04/02/FCECDA30AF6E_2_rotating_1648893457622.ubv
Move FCECDA30AF6E_2_rotating_2022-04-02T02.57.31-07.00.mp4, /mnt/ubnt-protect-out/video/2022/04/02/Interior DomeCam/02.57.31-07.00.mp4
run_cmd: remux -with-audio /mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2022/04/02/FCECDA30AF6E_2_rotating_1648918724648.ubv
Move FCECDA30AF6E_2_rotating_2022-04-02T09.58.33-07.00.mp4, /mnt/ubnt-protect-out/video/2022/04/02/Interior DomeCam/09.58.33-07.00.mp4

Source ubv files processed:     6855
Destination mp4 files created:  7906
Time:                           106820 seconds
```

Example of my input directory structure (disk mounted on /mnt/ubnt-protect-in):
```
/mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2022/01/13/E063DA3FEC8C_0_rotating_1642139195172.ubv
/mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2022/01/13/E063DA3FEC8C_0_rotating_1642145593157.ubv
/mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2021/06/01/FCECDA8FAD1D_2_rotating_1622569548072.ubv
/mnt/ubnt-protect-in/unifi-os/unifi-protect/video/2021/11/28/FCECDA8FAD1D_0_rotating_1638130012796.ubv
```

Example of the output directory structure (disk mounted on /mnt/ubnt-protect-out):
```
/mnt/ubnt-protect-out/video/2022/04/02/UVC G4 Pro - front driveway/02.15.37-07.00.mp4
/mnt/ubnt-protect-out/video/2022/04/02/UVC G4 Pro - front driveway/08.31.32-07.00.mp4
/mnt/ubnt-protect-out/video/2022/04/02/Interior DomeCam/00.30.17-07.00.mp4
/mnt/ubnt-protect-out/video/2022/04/02/Interior DomeCam/03.31.26-07.00.mp4
```
