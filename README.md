# daily-driver

A template driver script to update and maintain a daily archive of files 

## About

This README serves two purposes: to describe the template daily-driver script and how to use it, and to serve as a sample README for your own projects that you create using daily-driver as a template. The daily-driver template provides a script that is useful for running software that updates or maintains archives of data organized by date. If you want to write code that takes a date argument and then creates or updates a set of files, and you want to run this code automatically (e.g., as a cron job) with self-healing capabilities to keep track of gaps in the archive to try and fill in later runs, than this template is for you.

### Built With

* [Bash](https://www.gnu.org/software/bash/)
* Add other software you use in your project

## Getting Started

This section provides information for how to get daily-driver set up and working on your system. Be sure to add additional content based on the project you build from this template!

### Environment

This application is designed to run in the [bash shell](https://www.gnu.org/software/bash/). The bash shell is available on Linux and MacOS systems, on [Windows systems via Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install), and on ChromeOS via the [Crostini (Debian Linux based) container](https://support.google.com/chromebook/answer/9145439?hl=en).

### Prerequisites

The daily-driver application relies on other software that needs to be installed on your system.

#### Install git

See [Git - Installing git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) for more information about installing git on your system.

### Installation

1. Clone the repo:
```
     git clone git@github.com:avram-meir/daily-driver.git
```
2. Nothing else needs to be done to get daily-driver working, but add any additional installation instructions here for your own project.

## Usage

This section provides information about how to use the daily-driver application. Update and modify this for your own software project.

### How to run

#### Driver script

The entire functionality of daily-driver is governed by a bash script: `daily-driver.sh`. This script can be run on [cron](https://man7.org/linux/man-pages/man5/crontab.5.html) to update your date-based archives with new data, once you modify its child script `update-archives.sh` to do what you want it to do.

Features of `daily-driver.sh`:
* Run with no arguments, will run `update-archives.sh` passing it today's date via a `-d` option (e.g., ``update-archives.sh -d "`date +%Y%m%d`"``).
* To run different dates or a range of dates, supply a `-d` option.
* To have `daily-driver.sh` check your archives for a set of expected files and only run `update-archives.sh` for dates when those files are not there, supply a `-c` option.
* To have `daily-driver.sh` check and update the archives (or just run `update-archives.sh`) for a number of days prior to the earliest date in its list, supply a `-b` option.
* To keep track of dates where archive files fail to update or `update-archives.sh` returns a non-zero status (failure), supply a `-l` option.

As an example of how to use this script, consider this crontab entry:

```
0 0 * * * /path/to/daily-driver/daily-driver.sh -c /path/to/daily-driver/archive.config -b "-30 days" -l /path/to/daily-driver/missing_dates.txt
```

This usage would, daily at midnight, check the archives for missing files for the 30 days prior to today's date, today's date, and any dates in `/path/to/daily-driver/missing_dates.txt`, running `update-archives.sh` for any dates where missing files are found. The result of `update-archives.sh` would be checked as well as the archive to make sure the files got created, and any dates with problems or missing files would be written back to `/path/to/daily-driver/missing_dates.txt` for the next day's run.  

**Usage**

`./daily-driver.sh [options]`

**Options**

These are the options available for `daily-driver.sh`.

<table>
  <tr><th>Option&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th><th>Description</th></tr>
     <tr><td><code>-b &lt;string&gt;</code></td><td>Pass a valid <a href="https://man7.org/linux/man-pages/man1/date.1.html">GNU date</a> delta (e.g., '-30 days' or '10 days ago') and the script will scan the archive described by the configuration file provided through the -c option for missing files for that many days before the earliest date supplied through the -d option. If no -c option is supplied, the script will run <code>update-archives.sh</code> for each of those days. If no -d option is supplied, the date delta will apply to today's date (e.g., ./daily-driver.sh -b '-30 days' will run <code>update-archives.sh</code> for the 30 days leading up to today's date and today as well).</td></tr>
     <tr><td><code>-c &lt;filename&gt;</code></td><td>Pass a configuration file that lists all of the expected files in the archive. When updating for a date, the script will check for the existence of these files. If they do not exist, then the script will run <code>update-archives.sh</code> to try and create them. If they do exist, the script will do nothing and move to the next date in the list. See below for the format of the configuration file.</td></tr>
     <tr><td><code>-d &lt;date&gt;</code><br>&nbsp;&nbsp;&nbsp;&nbsp;or<br><code>-d &lt;date1 date2&gt;</code></td><td>Pass a date to update, or a start date and stop date to update for a range of days. The dates should be provided in a format understood by GNU date's --date option.</td></tr>
     <tr><td><code>-h</code></td><td>Print a usage statement and exit.</td></tr>
     <tr><td><code>-l &lt;filename&gt;</code></td><td>Pass a file containing a list of dates to update. Any dates where <code>update-archives.pl</code> fails will be written back to this file, while dates that have a successful run (or already have existing files in the archive defined by the -c option) will be removed from this file. This is a good way to keep track of gaps in your archives.</td></tr>
</table>

**Archive configuration file (what you pass with `-c`)**

The file passed using this option must provide a bash variable `$files` that contains a list of the archive files you want `daily-driver.sh` to check for. As this file is executed by `daily-driver.sh`, any bash script formatting can be used to set up this list. Each file in the list is passed to the GNU date command via [+FORMAT], so date [FORMAT wildcards](https://man7.org/linux/man-pages/man1/date.1.html) can be used in the filename. So, for example, if your configuration file contained the following:

```Shell
archive_path='/path/to/archive'
files=${archive_path}/%Y/%m/%d/file1.txt
files+=${archive_path}/%Y/%m/%d/file2.txt
```

And you ran `./daily-driver.sh -c /your/config/file -d 20220501`, then the script would check for the following files:

```
/path/to/archive/2022/05/01/file1.txt
/path/to/archive/2022/05/01/file2.txt
```

And would run `update-archives.sh` to try and create these files if they were not there.

**Missing date list file (what you pass with `-l`)**

The file passed using this option must provide a bash variable `$missingdates` that contains a list of the dates that you want `update-archives.sh` to check and run. This file need not exist, and if dates where archive updating fails occur during run time, they will get written to this file, overwriting whatever was there before. Note that this file is executed as a bash script by `daily-driver.sh`, so any bash script formatting works.

An example file created by `daily-driver.sh` when it tried and failed to update an archive for the first five days of May, 2022:

```
missingdates=(20220501 20220502 20220503 20220504 20220505)
```

#### Archive updating script

The driver script `daily-driver.sh` calls a second script, `update-archives.sh` and passes it a date argument (`-d <date>`). In this template, the script does nothing functional, but this is where you add your own functionality when building a project from this template. If you pass a `-c` argument to `daily-driver.sh`, `update-archives.sh` should be written to create or update those archive files.

Here is where you'll likely be adding your project's awesomeness to the README.

## Roadmap

See the [open issues](../../issues) for a list of proposed features and reported problems.

## Contributing

Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. [Open a Pull Request](../../pulls)

## Contact

Adam Allgood
