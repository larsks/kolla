FROM kollaglue/fedora-rdo-base
MAINTAINER Lars Kellogg-Stedman <lars@redhat.com>

RUN yum install -y openstack-keystone; yum clean all
ADD ./start.sh /start.sh

EXPOSE 5000 35357

CMD ["/start.sh"]
