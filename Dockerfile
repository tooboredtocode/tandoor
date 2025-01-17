FROM python:3.12-alpine3.19

#Install all dependencies.
RUN apk add --no-cache postgresql-libs postgresql-client gettext zlib libjpeg libwebp libxml2-dev libxslt-dev openldap git

#Print all logs without buffering it.
ENV PYTHONUNBUFFERED 1

ENV DOCKER true

#This port will be used by gunicorn.
EXPOSE 8080

#Create app dir and install requirements.
RUN mkdir /opt/recipes
WORKDIR /opt/recipes

COPY requirements.txt ./

RUN \
    if [ `apk --print-arch` = "armv7" ]; then \
    printf "[global]\nextra-index-url=https://www.piwheels.org/simple\n" > /etc/pip.conf ; \
    fi
# remove Development dependencies from requirements.txt
RUN sed -i '/# Development/,$d' requirements.txt
RUN apk add --no-cache --virtual .build-deps gcc musl-dev postgresql-dev zlib-dev jpeg-dev libwebp-dev openssl-dev libffi-dev cargo openldap-dev python3-dev && \
    echo -n "INPUT ( libldap.so )" > /usr/lib/libldap_r.so && \
    python -m venv venv && \
    /opt/recipes/venv/bin/python -m pip install --upgrade pip && \
    venv/bin/pip install wheel==0.42.0 && \
    venv/bin/pip install setuptools_rust==1.9.0 && \
    venv/bin/pip install -r requirements.txt --no-cache-dir &&\
    apk --purge del .build-deps

#Copy project and execute it.
COPY . ./

# collect the static files
RUN /opt/recipes/venv/bin/python manage.py collectstatic_js_reverse
RUN /opt/recipes/venv/bin/python manage.py collectstatic --noinput
# copy the collected static files to a different location, so they can be moved into a potentially mounted volume
RUN mv /opt/recipes/staticfiles /opt/recipes/staticfiles-collect

# collect information from git repositories
RUN /opt/recipes/venv/bin/python version.py
# delete git repositories to reduce image size
RUN find . -type d -name ".git" | xargs rm -rf

RUN chmod +x boot.sh
ENTRYPOINT ["/opt/recipes/boot.sh"]
