# CDUX

## Description
When in a `tmux` session, cdux can be used to open multiple directories simulataneously, in either panes or windows. Simply provide the paths you want to navigate to and the rest is done for you.

## Installation
Clone this repo and copy the `cdux` executable into `/usr/bin`
```
git clone `ssh` or `https`
cd cdux
cp cdux /usr/bin/
```

Permission errors can be caused by not having root privileges, either prefix `cp` with `sudo` or switch to root with `sudo su`.

## Usage
When in a tmux session
```
cdux ~/Documents ~/Downloads
```
Will open two new panes in your current tmux session, one in `~/Documents`, the other in `~/Downloads`

```
cdux -w ~/Documents ~/Downloads
```
Will open each location in a new window in tmux, instead of having them be added to your current window

```
cdux -c 4 ~/Documents/*
```
Will open all directories in `~/Documents` but will only allow 4 panes per window

## Support
For feature requests or bug reports, create a new issue that describes, in as much detail as possible, the desired feature/undesired behaviour

## Authors and acknowledgment
Joshua Zivkovic

## License
Use this how you want
