

# SSHFS (on Mac)

For this also please look at this [guide](https://phoenixnap.com/kb/sshfs-mac)
1.  Install both macFuse and SSHFS (SSH file system) from [here](https://macfuse.github.io)
2.  Follow the directions in there to create the mount. For example, I ran the following to create two new mountpoints:

```bash
sshfs larsve@snellius.surf.nl:/gpfs/work3/0/prjs0823 snellius_protein
sshfs larsve@snellius.surf.nl:/gpfs/home2/larsve snellius_home
```

It is important here to use the “real” path. To find the real path of a folder on Snellius use the `realpath` command e.g.:

```bash
[larsve@int4 ~]$ pwd # not this
/home/larsve
[larsve@int4 ~]$ realpath . # but this
/gpfs/home2/larsve
[larsve@int4 ~]$
```

So I use the second one (`/gpfs/home2/larsve`) as can be seen above.

3. I can now `cd`/`ls` into these locations (locally):

```bash
➜  ~ ls snellius_protein 
MLProtein_Suite   MLProtein_Suite_2 gi                home2             scripts           test
```

4. You can also find the mounts in Finder as shown by the tutorial above. If you don’t see the name of your Mac under “locations” you might need to add it to the sidebar as follows:  
4.1.  Open Finder  
4.2. Go **Finder > Settings > Sidebar** and then check the mark next to the name of your laptop.

---









