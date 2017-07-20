FROM maven:alpine

# Add an unprivilged user, install needed packages and set up python virtualenv
RUN adduser -S deploy; \
    apk --no-cache add bash curl git make python py-pip; \
    pip install virtualenv; \
    virtualenv packaging/deploy; \
    packaging/deploy/bin/pip install --upgrade sceptre awscli awsebcli

# Switch to our user and setup their home directory a bit to activate virtualenv on login
USER deploy

RUN echo "source packaging/deploy/bin/activate" > ~/.bashrc; \
    mkdir ~/.pip; echo -e "[list]\nformat=columns" > ~/.pip/pip.conf

VOLUME ["/src"]

ENTRYPOINT ["bash"]