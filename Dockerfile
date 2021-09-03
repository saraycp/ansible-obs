FROM registry.opensuse.org/opensuse/leap:15.3

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=foo

RUN zypper -n install openssh-clients ansible ruby ruby-devel bash git libxml2-devel gcc make shadow vim curl ruby2.5-devel

RUN gem install bundler

# Ensure there are ruby, bundler and bundle commands without ruby suffix
RUN for i in ruby bundler bundle; do ln -s /usr/bin/$i.ruby2.5 /usr/local/bin/$i; done

RUN zypper -q clean -a

RUN useradd -l -u ${USER_ID} -g users --home-dir /home/${USER_NAME} --create-home ${USER_NAME}

RUN git config --global url."https://${GITHUB_TOKEN}:@github.com/".insteadOf "https://github.com/"

WORKDIR /home/ansible-obs
ADD Gemfile /home/ansible-obs
ADD Gemfile.lock /home/ansible-obs
RUN bundle install
RUN bundle install --binstubs

ADD "entrypoint.sh" /

ENTRYPOINT ["bash", "-c", "/entrypoint.sh"]
