# Adapted from https://github.com/akabe/docker-ocaml/blob/master/dockerfiles/ubuntu16.04_ocaml4.06.1/Dockerfile

FROM ubuntu:16.04


ENV OPAM_VERSION  1.2.2
ENV OCAML_VERSION 4.06.1+flambda
ENV Z3_VERSION    4.6.0


ENV HOME /home/opam


RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y aspcud binutils cmake curl g++ git libgmp-dev libgomp1 \
                       libomp5 libomp-dev libx11-dev m4 make patch python2.7  \
                       sudo unzip

RUN adduser --disabled-password --home $HOME --shell /bin/bash --gecos '' opam && \
    echo 'opam ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

RUN curl -L -o /usr/bin/opam "https://github.com/ocaml/opam/releases/download/$OPAM_VERSION/opam-$OPAM_VERSION-$(uname -m)-$(uname -s)" && \
    chmod 755 /usr/bin/opam

RUN su opam -c "opam init -a -y --comp $OCAML_VERSION"

RUN find $HOME/.opam -regex '.*\.\(cmt\|cmti\|annot\|byte\)' -delete && \
    rm -rf $HOME/.opam/archives \
           $HOME/.opam/repo/default/archives \
           $HOME/.opam/$OCAML_VERSION/man \
           $HOME/.opam/$OCAML_VERSION/build

RUN apt-get autoremove -y && \
    apt-get autoclean


USER opam
WORKDIR $HOME


RUN opam install alcotest.0.8.3 core.v0.11.0 core_extended.v0.11.0 jbuilder.1.0+beta19.1

RUN curl -LO https://github.com/Z3Prover/z3/archive/z3-$Z3_VERSION.zip && \
    unzip z3-$Z3_VERSION.zip && mv z3-z3-$Z3_VERSION z3-$Z3_VERSION
RUN git clone https://github.com/SaswatPadhi/LoopInvGen.git LoopInvGen

RUN eval `opam config env` && cd LoopInvGen && \
    ./create-package.sh --optimize --make-z3 ../z3-$Z3_VERSION \
                        --jobs `cat /proc/cpuinfo | grep processor | wc -l`


WORKDIR $HOME/LoopInvGen
ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD [ "bash" ]