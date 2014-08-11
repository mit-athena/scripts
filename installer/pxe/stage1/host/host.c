/* A minimal DNS resolver for the stage1 installer, needed to bootstrap
 * network configuration.
 *
 * Loosely based on ahost.c from the ares library.
 *
 * Copyright 2014, Massachusetts Institute of Technology.
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <strings.h>
#include <string.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <ares.h>
#include <ares_dns.h>

#define STATUS_ERROR 64
#define STATUS_NOT_FOUND 128
#define STATUS_NOT_IP 1
#define STATUS_OK 0

extern int optind;

/* default DNS servers to use */
const char *DEFAULT_NS = "18.70.0.160,18.71.0.151,18.72.0.3";
const char *DEFAULT_DOMAIN = "mit.edu";

int sh_output = 0;

static void callback(void *arg, int status, int timeouts, struct hostent *host)
{
  char addr_buf[INET_ADDRSTRLEN] = "a'b";
  char *alias = "";
  if (status != ARES_SUCCESS) {
    *(int *)arg = status == ARES_ENOTFOUND ? STATUS_NOT_FOUND : STATUS_ERROR;
    fprintf(stderr, "%s\n", ares_strerror(status));
    return;
  } else {
    *(int *)arg = STATUS_OK;
  }

  if (host->h_addr_list[0] != NULL) {
      ares_inet_ntop(host->h_addrtype, host->h_addr_list[0],
		     addr_buf, sizeof(addr_buf));
  }
  if (host->h_aliases[0] != NULL &&
      (strcasecmp(host->h_aliases[0],
		  host->h_name) != 0)) {
    alias = host->h_aliases[0];
  }
  if (sh_output) {
    if ((strchr(host->h_name, '\'') != NULL) ||
	(strchr(addr_buf, '\'') != NULL)) {
      fprintf(stderr, "Unable to escape values!\n");
      *(int *)arg = STATUS_ERROR;
    } else {
      printf("DAIPADDR='%s'; DAHOSTNAME='%s'\n", addr_buf, host->h_name);
    }
  } else {
    printf("%s\t%s\t%s\n", addr_buf, host->h_name, alias);
  }
}

void process_queries(ares_channel channel) {
  int nfds;
  fd_set read_fds, write_fds;
  struct timeval *tvp, tv;
  /* Wait for all queries to complete. */
  while (1) {
    FD_ZERO(&read_fds);
    FD_ZERO(&write_fds);
    nfds = ares_fds(channel, &read_fds, &write_fds);
    if (nfds == 0)
      break;
    tvp = ares_timeout(channel, NULL, &tv);
    select(nfds, &read_fds, &write_fds, NULL, tvp);
    ares_process(channel, &read_fds, &write_fds);
  }
}


int lookup_host_or_ip(char *host_or_ip, int ip_only) {
  int is_ip;
  int addr_family = AF_INET;
  struct in_addr ipv4_addr;
  int status;
  ares_channel channel;
  struct ares_options options;
  char *domain;
  char *nameservers_csv;

  is_ip = inet_pton(addr_family, host_or_ip, &ipv4_addr);
  if (is_ip < 0) {
    perror("inet_pton");
    return STATUS_ERROR;
  }
  if (ip_only) {
    return is_ip ? STATUS_OK : STATUS_NOT_IP;
  }
  /* Initialize library */
  status = ares_library_init(ARES_LIB_INIT_ALL);
  if (status != ARES_SUCCESS) {
    fprintf(stderr, "ares_library_init: %s\n", ares_strerror(status));
    return 1;
  }
  /* Set the search domain */
  options.ndomains = 1;
  domain = getenv("DEBATHENA_DOMAIN");
  if (domain == NULL) {
    domain = (char *) DEFAULT_DOMAIN;
  }
  options.domains = &domain;
  status = ares_init_options(&channel, &options, ARES_OPT_DOMAINS);
  if (status != ARES_SUCCESS) {
    fprintf(stderr, "ares_init_options: %s\n", ares_strerror(status));
    return 1;
  }
  nameservers_csv = getenv("DEBATHENA_NAMESERVERS");
  if (nameservers_csv == NULL) {
    nameservers_csv = (char *) DEFAULT_NS;
  }
  status = ares_set_servers_csv(channel, nameservers_csv);
  if (status != ARES_SUCCESS) {
    fprintf(stderr, "ares_set_servers_csv: %s\n", ares_strerror(status));
    return 1;
  }
  
  status = STATUS_ERROR;  /* The callback must set this to something else. */
  if (is_ip) {
    ares_gethostbyaddr(channel, &ipv4_addr, sizeof(ipv4_addr),
		       addr_family, callback, &status);
  } else {
    ares_gethostbyname(channel, host_or_ip, addr_family, callback,
		       &status);
  }
  process_queries(channel);
  ares_destroy(channel);
  ares_library_cleanup();
  return status;
}

int main(int argc, char *argv[])
{
  int ip_only = 0;
  int usage = 0;
  int opt;

  while ((opt = getopt(argc, argv, "is")) != -1) {
    switch (opt) {
    case 'i':
      ip_only = 1;
      break;
    case 's':
      sh_output = 1;
      break;
    default:
      usage = 1;
      break;
    }
  }

  if ((argc - optind != 1) || usage) {
    fprintf(stderr, "Usage: %s [-i] host-or-ip\n", argv[0]);
    return STATUS_ERROR;
  }

  return lookup_host_or_ip(argv[optind], ip_only);
}
