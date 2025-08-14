## Table of Contents
- [Transferring files](#transferring-files)
    - [Local-To-Snellius & Snellius-To-Local](#local-to-snellius--snellius-to-local)
        - [Naive Approach](#naive-approach)
        - [Packed data streaming](#packed-data-streaming)
            - [Compression](#compression)
            - [Multi-threaded Compression/Decompression](#multi-threaded-compressiondecompression)
        - [Multi-stage transfers](#multi-stage-transfers)
            - [Transferring to the system](#transferring-to-the-system)
            - [Unpacking on the system](#unpacking-on-the-system)
    - [Rsync and rclone](#rsync-and-rclone)
    - [Additional remarks](#additional-remarks)


# Transferring files

## Local-To-Snellius
While it is fine to transfer files via SSHFS (via Finder or otherwise) if you only need to move a small amount of data, you should refrain from using it to transfer many and/or large files as it can be very slow. This is partially due to the fact that it cannot parallelize uploading small files, but it’s also missing a lot of efficiency improvements compared to other tools.

While there are ways to parallelize the uploading/downloading of small files to make uploading much faster using tools like `rclone` or `rsync`, when doing Snellius-to-local or local-to-Snellius transfers you will typically be stuck using the Snellius login nodes. These nodes are a shared resource between all users and can quickly be overloaded when dealing with a lot of small files, which will significantly other users. Therefore, you are supposed to do those types of tasks in an actual compute job, for example on a staging node (see the warning [here](https://servicedesk.surf.nl/wiki/spaces/WIKI/pages/92668162/Transfer+files+between+to+and+from+the+system)). However, from there you cannot really access your local files. 

As a result, the recommended aproach is to pack the smaller files into one archive (e.g. `tar.gz`, `zip`, `rar`). This doesn't have to include compression, but it can be helpful if your connection is slow (and thus the reduction in size/time spent 'uploading' outweighs the additional time spent on compression and decompression). 


### Naive Approach
---
Using the regular `scp` (secure copy over SSH) command you can do this in one go for a relatively small folders with still a lot of files. As an example I'll use a local environment (this does not make sense as the environment won't work properly as paths are hardcoded and the environment is hardware dependent):

Moving `tensorboard_env` folder to Snellius (86MB, 2437 files) in the naive way using `scp [FLAGS] [source] [destination]` where both `source` or `destination` can be local or a remote location with the format `[user]@[server]:[location_on_server]`. 
```bash
➜  ~ time scp -r -q Documents/tensorboard_env  lveefkind@snellius.surf.nl:test
scp -r -q Documents/tensorboard_env lveefkind@snellius.surf.nl:test  0.24s user 2.57s system 1% cpu 3:30.85 total

```
Here we can see it took ***3.5 minutes*** to move this small amount of data.

Note: If you have an ssh config file with pre-configured servers you can also directly use those as `destination` or `source`.  I will assume this from now and replace `lveefkind@snellius.surf.nl` with `snellius`.

### Packed data streaming
---
Instead, let's stream a packed version of this data directly to Snellius:

```bash
➜  ~ time tar -C Documents -cf - tensorboard_env | ssh snellius 'mkdir -p test && tar xf - -C test'
tar -C Documents -cf - tensorboard_env  0.05s user 0.54s system 12% cpu 4.592 total
ssh snellius 'mkdir -p test && tar xf - -C test'  0.00s user 0.00s system 0% cpu 4.700 total
```

Now we're down to ***4.7 seconds***, from ***3.5 minutes***. But what is happening here exactly?

The *first* part of the command, `tar -C Documents cf - tensorboard_env` first enters the `Documents` directory (`-C Documents` ), then from there packs the directory `tensorboard_env` to an archive (`c` flag), writes it to stdout (`f -` argument). The pipe (`|`) then sends/pipes the output to the next command.

This command (`ssh snellius 'mkdir -p test && tar xf - -C test`) connects to Snellius using ssh (`ssh snellius`), connecting it to a login node, and executes the commands `mkdir -p test` (creating a directory) and `tar xf - -C test`. This unpacks/extracts (`x`) the data from stdin (`f -`) and writes it to a `test` directory (`-C test`).

#### Compression


This command can be adapted in many ways, including by adding compression using the `z` flag. The former will pack and compress the archive using gzip compression on the local side and decompress it on the system (both using the `z` flag for `gzip` compression). Compression and decompression takes some CPU time, but reduces the data footprint. It can help speed up the total transfer time if your connection is slow and hardware is relatively fast.

```bash
➜  ~ time tar -C Documents -zcf - tensorboard_env | ssh snellius 'mkdir -p test && tar zxf - -C test'
tar -C Documents -zcf - tensorboard_env  1.67s user 0.23s system 37% cpu 5.093 total
ssh snellius 'mkdir -p test && tar zxf - -C test'  0.00s user 0.00s system 0% cpu 5.377 total
```

Turns out that in this case it is a bit slower, but I am testing this from a fast connection (at the SURF office) on a small amount of data from my Macbook Pro M4.


### Multi-stage transfers
---
In the previous examples we were still using the Snellius login nodes to do the unpacking, which is problematic for larger datasets. So instead we'll save the compressed/packed data to Snellius, and then unpack it there using a job allocation on a *staging* node. As an example, I will use an image dataset that is 3.9GB and 20012 files. Doing this naively using scp takes over ***19 minutes***:

```bash
➜  Documents time scp -qr img_dataset/ snellius.surf.nl:test
scp -qr img_dataset/ snellius.surf.nl:test  1.65s user 22.92s system 2% cpu 19:22.15 total

```


#### Transferring to the system

We can also pack the data locally and and sending it as-is to the system in a single command. I will still do this for the environment, as it is still quite slow:
```bash
time tar -C Documents -zcf - tensorboard_env | ssh snellius 'mkdir -p test && cat > test/tensorboard_env.tar.gz' 
```

Here we replaced the untarring with `cat > test/tensorboard_env.tar.gz`, which writes a (compressed) tarball directly to the system, allowing us to unpack/decompress it later. However, for very large/long transfers this approach can still be problematic for various reasons. First of all, the files are still streamed as single files, slowing down the uploading. Furthermore, any ssh interruptions can result in a crash, resulting in lost progress on both packing/compression and transferring. 

Therefore, for larger datasets we can further split this into two sequential parts (executed as one command using `&&` to time it). I will do this for the image dataset now.

```bash
➜  Documents time tar -cf img_dataset.tar img_dataset 
tar -cf img_dataset.tar img_dataset  0.71s user 10.37s system 21% cpu 52.048 total
➜  Documents time scp img_dataset.tar snellius.surf.nl:test/
img_dataset.tar                                 100% 3923MB  64.8MB/s   01:00    
scp img_dataset.tar snellius.surf.nl:test/  0.29s user 4.03s system 7% cpu 1:01.24 total
```

Now it takes a total of about ***2 minutes*** instead of ***19 minutes*** to transfer this dataset. However, we still need to unpack it on the system.

Note that here I do not use compression due to my fast connection: in transfer time:

```bash
➜  Documents time tar -zcf img_dataset.tar.gz img_dataset
tar -zcf img_dataset.tar.gz img_dataset  102.13s user 9.79s system 58% cpu 3:10.70 total
➜  Documents time scp img_dataset.tar.gz snellius.surf.nl:test/
img_dataset.tar.gz                              100% 3459MB  72.1MB/s   00:47    
scp img_dataset.tar.gz snellius.surf.nl:test/  0.25s user 3.53s system 7% cpu 48.895 total
```

Here, compression of this dataset alone already takes more than 3 minutes, which does not outweigh the 12 second reduction .

#### Unpacking on the system
Now that we have the packed/compressed file on the system we create a job to unpack it. As both the gzip compression and tarring/untarring are single threaded, we do not require more cores. Using an allocation on the staging nodes is therefore most useful as we can reserve a single core, either using `salloc` for an interactive job or with batch jobs. I will show `salloc` here:
```bash
[larsve@int5 ~]$ salloc -p staging
.... # Skipping SLURM info
salloc: Granted job allocation 14059715
salloc: Waiting for resource configuration
salloc: Nodes srv3 are ready for job
Your terminal session is monitored

[larsve@srv3 test]$ time tar xf img_dataset.tar

real	0m33.260s
user	0m0.282s
sys	0m9.392s

```

So unpacking took another ***33 seconds***, bringing our total to ***2.5 minutes*** instead of ***19 minutes***. 

When unpacking the ***compressed*** version:

```bash
[larsve@srv6 test]$ time tar zxf img_dataset.tar.gz 

real	0m55.731s
user	0m31.352s
sys	0m10.065s
```

Which takes ***55 seconds***.



#### Multi-threaded Dompression/Decompression
We've now used gzip for compression/decompression, which is single threaded and therefore can take quit some time. Of course we can also replace this with multi-threaded compression algorithms such as `zstd`, which is installed by default on Snellius and can be installed on MacOS using `brew install zstd`. This allows us to run this locally:

```bash
➜  Documents time tar --use-compress-program="zstd -T0 -1" -cf img_dataset.tar.zstd img_dataset/
tar --use-compress-program="zstd -T0 -1" -cf img_dataset.tar.zstd img_dataset  4.85s user 10.79s system 37% cpu 42.086 total
```
Taking only ***42 seconds*** to compress and pack, which is significantly faster than gzip compression at ***3 minutes***, and also faster compared to regular tarring at ***52 seconds***.

Here, `--use-compress-program="zstd -T0 -1"` tells us to use `zstd` with all available cores (`-T0`) and compression level `1`. This is the lowest compression level with the fastest compression speed, but the highest file sizes (but still smaller than no compression). Level 19 is the highest.


Then after transferring, which should be slightly faster compared to the uncompressed variant, we can unpack it on the system on a staging node with more cores (let's do 16 for now):
```bash
[larsve@srv6 test]$ time tar --use-compress-program="pzstd -d" -xf img_dataset.tar.zstd

real	0m32.134s
user	0m5.934s
sys	0m14.873s
```
Taking about the same time as unpacking the non-compressed version.
Note that here I used `pzstd` instead of `zstd` as `zstd` *decompression* is actually singlethreaded by default, but `pzstd` (parallel zstd) is parallelized.


## Snellius-to-local

The Snellius-to-local transfer works essentially the exact same way, except we reverse directions. This means that for the single 'naive' approaches we only need to swap the destination and remote, e.g.:
```bash
➜  ~ time scp -r -q lveefkind@snellius.surf.nl:test/img_dataset Documents/ 
```

and for the multi-stage processes we have to first pack the data on Snellius (where we can typically easily use parallelization due to the speed of the system to effectively use compression):
```bash
[larsve@srv6 test]$ time tar --use-compress-program="zstd -T0 -3" -cf img_dataset.tar.zstd img_dataset/

real	0m16.444s
user	0m24.515s
sys	0m9.902s
```
Which takes only ***16 seconds*** to compress instead of the ***42 seconds*** it took locally.

Then we have to transfer it back to local from our local device:

```bash
➜  Documents time scp snellius.surf.nl:test/img_dataset.tar.zstd ~/Documents

```

# Rsync and rclone
While scp is the standard for copying safely over ssh, there are also other and more optimized commands available such as `rsync` and `rclone`. We have some documentation on those tools [here](https://servicedesk.surf.nl/wiki/spaces/WIKI/pages/92668162/Transfer+files+between+to+and+from+the+system). `rclone` is typically better for moving many smaller files within the system, as it can do great parallelization, or from other clusters/storage provides. You can configure endpoints with many different policies (e.g. ssh). Unfortunately, it does not support OTP over ssh.

`rsync` is an optimized protocol for transferring files over ssh. It is typically faster compared to `scp`, and also has features such as easy resuming of interrupted transfers. You should only use `rsync` in a job though and not on the login nodes.

# Additional remarks
There are quite a few additional factors that determine the transfer speed, such as:

1. Your own internet connection. Ethernet is favored.
2. The current load on the system, particularly the interactive nodes.





