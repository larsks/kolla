FROM kollaglue/fedora-rdo-nova-ctr-base
MAINTAINER Ryan Hallisey <rhallisey@redhat.com>

RUN yum -y install \
        openstack-nova-conductor && yum clean all

ADD ./start.sh /start.sh
CMD ["/start.sh"]
