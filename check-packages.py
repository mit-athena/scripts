#!/usr/bin/python

# A script that sanity-checks the source tree against the APT
# repo to find version skew, unbuilt packages, etc.
#
# This replaces the old check-unbuilt-packages and ood-packages
# scripts.
#
# The script assumes the changelog is retreivable by http[s].
# The branch used defaults to 'master' and can be changed.
# An alternate package file can be specified.
#
# By default, the script will skip changelog entries marked
# as "UNRELEASED" under the assumption that someone is still
# working on them.
#
# The script will list packages that have version skew, and what that
# skew is.  Enabling verbose mode will show you which versions are in
# which suites in the repository.

import debian.changelog
import debian.debian_support
import subprocess
import urllib2
import sys
import os
import re
from optparse import OptionParser

GITHUB_URI="https://raw.github.com/mit-athena"
DEFAULT_REPO_BRANCH="master"
DEFAULT_PACKAGES_FILE="/mit/debathena/packages/packages"

options = {}

def get_repo_ver(reponame, skip_unreleased=False):
    response = urllib2.urlopen("/".join([GITHUB_URI, reponame, options.repo_branch, "debian/changelog"]))
    cl = debian.changelog.Changelog(response.read())
    ver = cl.version
    distr = cl.distributions
    if (distr == "UNRELEASED") and skip_unreleased:
        for block in cl:
            new_cl = debian.changelog.Changelog(str(block))
            if new_cl.distributions != "UNRELEASED":
                ver = new_cl.version
                distr = new_cl.distributions
                break
    return (ver, distr)

def get_apt_versions(package, restrict_to_supported=True):
    codes = os.getenv('DEBIAN_CODES', '')
    if restrict_to_supported and (codes == ''):
        sys.exit("DEBIAN_CODES is not set")
    supported_list = codes.split(' ')
    try:
        reprepro = subprocess.check_output(["dareprepro", "ls", package])
    except subprocess.CalledProcessError as e:
        sys.exit("Invoking reprepro failed: " + e.message)
    versions = {}
    for line in reprepro.splitlines():
        [package, ver, suite, arch] = [x.strip() for x in line.split('|')]
        # We only care about source packages for now
        # Yes, in, because equivs packges show up as "amd64,i386,source"
        if 'source' not in arch:
            continue
        if restrict_to_supported:
            if suite.split('-')[0] not in supported_list:
                continue
        if ver not in versions:
            versions[ver] = []
        versions[ver].append(suite)
    return versions

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("--no-skip-unreleased", action="store_false", default=True, 
                      dest="skip_unreleased")
    parser.add_option("--skip-missing", action="store_true", default=False, 
                      dest="skip_missing")
    parser.add_option("-v", "--verbose", action="store_true", default=False,
                      dest="verbose")
    parser.add_option("-f", "--packages-file", action="store", type="string",
                      default=DEFAULT_PACKAGES_FILE, dest="packages_file")
    parser.add_option("-b", "--repo-branch", action="store", type="string",
                      default=DEFAULT_REPO_BRANCH, dest="repo_branch")
    (options, args) = parser.parse_args()

    with open(options.packages_file, 'r') as p:
        for line in p.readlines():
            (package, repopath) = line.strip().split()
            repo_match = re.match(r'/git/athena/(.*).git$', repopath)
            if repo_match is None:
                sys.exit("No idea what to do with repo path: " + repopath)
            reponame = repo_match.group(1)
            repo_ver = get_repo_ver(reponame, options.skip_unreleased)
            pkg_ver = get_apt_versions(package)
            if (len(pkg_ver.keys()) == 0) and options.skip_missing:
                continue
            if (len(pkg_ver.keys()) == 1) and (repo_ver[0] == pkg_ver.keys()[0]):
                # Versions match
                continue
            if options.verbose:
                print "%s\n\tGit: %s%s" % (package, repo_ver[0], '(*)' if repo_ver[1] == "UNRELEASED" else '')
                if len(pkg_ver.keys()):
                    for k,v in pkg_ver.iteritems():
                        print "\tAPT: %s %s" % (k, v)
                else:
                    print "\tAPT: *MISSING*"
            else:
                print "%s is %s%s in Git and %s in APT" % (package, repo_ver[0], '(*)' if repo_ver[1] == "UNRELEASED" else '', ', '.join(pkg_ver.keys()) if len(pkg_ver.keys()) > 0 else '*MISSING*')
