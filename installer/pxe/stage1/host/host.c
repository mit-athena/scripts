#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <netdb.h>
#include <sys/socket.h>
#include <arpa/nameser.h>
#include <arpa/inet.h>
#include <resolv.h>

#define STATUS_ERROR 1
#define STATUS_NOT_FOUND 128
#define STATUS_OK 0

extern int h_errno;

/* max nameservers we'll set (greater of 3 or MAXNS from resolv.h)
   N.B. the maximum timeout will be this * 5) */
const int MAX_NS = MAXNS <= 3 ? MAXNS : 3;
/* default DNS servers to use */
const char *DEFAULT_NS = "18.70.0.160,18.71.0.151,18.72.0.3";
/* delimiter for namesever list */
const char *NS_DELIM = ",";
/* DNS port number */
const int DNS_PORT = 53;

/* Using the _res structure, set the nameservers to values we want, as
   opposed to what is in resolv.conf */
int set_new_nameservers() {
  const char *use_nameservers = NULL;
  char *nameservers = NULL;
  char *nameserver = NULL;
  int rv;
  struct sockaddr_in *sa;

  use_nameservers = getenv("DEBATHENA_NAMESERVERS");
  if (use_nameservers == NULL) {
    use_nameservers = (char *)DEFAULT_NS;
  }

  /* Make a copy of the string, since strtok() will modify it. */
  nameservers = strdup(use_nameservers);
  if (nameservers == NULL) {
    perror("strdup");
    return STATUS_ERROR;
  }

  /* Parse the string for comma-separated IP addresses, setting the
     nameservers as we go along. */
  nameserver = strtok(nameservers, NS_DELIM);
  _res.nscount = 0;
  while (nameserver != NULL) {
    if (_res.nscount >= MAX_NS) {
      fprintf(stderr, "error: too many nameservers (%d max)\n", MAX_NS);
      return STATUS_ERROR;
    }
    sa = malloc(sizeof(*sa));
    if (sa == NULL) {
      perror("malloc");
      return STATUS_ERROR;
    }
    /* We don't support IPv6 */
    sa->sin_family = AF_INET;
    sa->sin_port = htons(DNS_PORT);
    rv = inet_pton(AF_INET, nameserver, &sa->sin_addr);
    if (rv == 1) {
      /* Force the nameserver to what we just set */
      memcpy(&_res.nsaddr_list[_res.nscount++], sa, sizeof(*sa));
    } else if (rv == 0) {
      fprintf(stderr, "ignoring invalid IP address: %s\n", nameserver);
    } else {
      perror("inet_pton");
      return STATUS_ERROR;
    }
    free(sa);
    /* Find the next token */
    nameserver = strtok(NULL, NS_DELIM);
  }
  if (_res.nscount == 0) {
    fprintf(stderr, "No nameservers defined.\n");
    return STATUS_ERROR;
  }
  return STATUS_OK;
}

int lookup_host_or_ip(char *host_or_ip) {
  int i;
  int rv;
  char ip_str[INET_ADDRSTRLEN] = "";
  struct hostent *host;
  struct in_addr *address;

  address = malloc(sizeof(struct in_addr));
  if (address == NULL) {
    perror("malloc");
    return STATUS_ERROR;
  }
  /* See if it's a valid IP address */
  rv = inet_pton(AF_INET, host_or_ip, address);
  if (rv < 0) {
    perror("inet_pton");
    return STATUS_ERROR;
  }
  if (rv == 1) {
    host = gethostbyaddr(address, sizeof(struct in_addr), AF_INET);
  } else {
    host = gethostbyname(host_or_ip);
  }
  if (host == NULL) {
    switch (h_errno) {
    case HOST_NOT_FOUND:
      fprintf(stderr, "Host not found\n");
      return STATUS_NOT_FOUND;
    default:
      fprintf(stderr, "An unknown error occurred\n");
      return STATUS_ERROR;
      break;
    }
  } else {
    /* Only take the first IP address. */
    if (host->h_addr_list[0] != NULL) {
      inet_ntop(AF_INET, host->h_addr_list[0], ip_str, INET_ADDRSTRLEN);
    }
    printf("%s\t%s\t%s\n", ip_str, host->h_name,
	   host->h_aliases[0] == NULL ? "" : host->h_aliases[0]);
  }
  free(address);
  return STATUS_OK;
}

int main(int argc, char *argv[])
{
  if (argc != 2) {
    fprintf(stderr, "Usage: %s host-or-ip\n", argv[0]);
    return STATUS_ERROR;
  }
  /* GLIBC: The first call to gethostby{name,addr} reinitializes the
     _res structure.  So we need to call it once before setting the
     DNS servers.  This is hinted at, but not explicitly stated, in
     res_mkquery(3).  (It does not matter if you've already called
     res_init, it will get called again anyway.)

     See: https://bugs.busybox.net/show_bug.cgi?id=675 */
  (void) gethostbyname("localhost");
  /* Call res_init() again */
  res_init();
  /* Set our nameservers */
  if (set_new_nameservers() != 0) {
    fprintf(stderr, "Failed to set name servers\n");
    return STATUS_ERROR;
  }
  return lookup_host_or_ip(argv[1]);
}
