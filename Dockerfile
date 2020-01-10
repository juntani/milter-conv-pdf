FROM ubuntu:latest
RUN apt-get -y update
RUN apt-get -y install libreoffice libreoffice-l10n-ja
RUN apt-get -y install libreoffice-core --no-install-recommends
RUN apt-get -y install fonts-takao
# apt install openjdk
RUN mkdir /data
ENTRYPOINT ["libreoffice", "--headless", "--nologo", "--nofirststartwizard", "--convert-to", "pdf", "--outdir", "/data"]
