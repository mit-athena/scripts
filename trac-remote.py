#!/usr/bin/python

import sys, os
import xmlrpclib
import logging
from optparse import OptionParser

LOGGER_NAME="trac-remote"
DEFAULT_CREDENTIALS=os.getenv('HOME', '') + "/.trac-credentials"
DEFAULT_SERVER="athena10.mit.edu"
DEFAULT_RPC_PATH="/trac/login/rpc"

logger = logging.getLogger(LOGGER_NAME)

class Trac:
    use_SSL = True

    valid_repos = ("-development", "-proposed", "production")

    def __init__(self, credentials):
        scheme = "http"
        if self.use_SSL:
            scheme="https"
        self._uri = "%s://%s:%s@%s%s" % (scheme,
                                         credentials[0],
                                         credentials[1],
                                         DEFAULT_SERVER,
                                         DEFAULT_RPC_PATH)
        logger.debug("URI: %s", self._uri)
        self._server = xmlrpclib.ServerProxy(self._uri)

    def _update(self, ticket_id, comment, fields, notify=True, author=""):
        # Setting author requires TICKET_ADMIN or higher for the XML
        # RPC user, otherwise it will be ignored and the username of the
        # XML RPC user will be substituted
        try:
            response = self._server.ticket.get(ticket_id)
            # Returns [id, time_created, time_changed, attributes]
            fields["_ts"] = response[3]["_ts"]
            if "action" not in fields or (fields["action"] == response[3]["status"]):
                fields["action"] = "leave"
            self._server.ticket.update(ticket_id, comment, fields, notify, author)
        except xmlrpclib.Fault, e:
            print >>sys.stderr, e.message
            sys.exit(1)

    def upload_to_development(self, ticket_id, version):
        self._update(ticket_id, "Uploaded to -development",
                     {"fix_version": version,
                      "action": "development"})

    def upload_to_proposed(self, ticket_id, version):
        self._update(ticket_id, "Uploaded to -proposed",
                     {"fix_version": version,
                      "action": "proposed"})

    def upload_to_production(self, ticket_id, version):
        self._update(ticket_id, "Uploaded to production",
                     {"fix_version": version,
                      "action": "resolve",
                      "action_resolve_resolve_resolution": "fixed"})

    def commit_to_master(self, ticket_id, comment, author):
        self._update(ticket_id, comment,
                     {"action": "committed"}, True, author)


if __name__ == '__main__':
    parser = OptionParser()
    parser.set_defaults(debug=False)
    parser.add_option("--debug", action="store_true", dest="debug")
    parser.add_option("--credentials", action="store", type="string",
                      default=DEFAULT_CREDENTIALS, dest="credentials")
    (options, args) = parser.parse_args()
    logging.basicConfig(level=logging.WARN, format='%(asctime)s %(levelname)s:%(name)s:%(message)s')
    if options.debug:
        logger.setLevel(logging.DEBUG)
    if len(args) < 1:
        print >>sys.stderr, "Syntax Error"
        sys.exit(1)
    try:
        f = open(options.credentials, "r")
        creds = f.readline().rstrip().split(':', 1)
        f.close()
    except IOError, e:
        print >>sys.stderr, "Error reading credentials file:", e
        sys.exit(1)
    if len(creds) != 2:
        print >>sys.stderr, "Malformatted credentials file."
        sys.exit(1)
    t = Trac(creds)
    cmd = args.pop(0)
    try:
        getattr(t, cmd)(*args)
    except AttributeError:
        print >>sys.stderr, "Invalid command: " + cmd
        sys.exit(1)
    except TypeError, e:
        print >>sys.stderr, "Syntax Error: " + e.message
        sys.exit(1)
    sys.exit(0)
