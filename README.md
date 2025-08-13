[![CircleCI](https://circleci.com/gh/openSUSE/ansible-obs.svg?style=svg)](https://circleci.com/gh/openSUSE/ansible-obs)

## Installation

Build the docker image

```shell
docker-compose build --no-cache
```

⚠️ Note: The container will run with a user with your username, the UID 1000 and the GID 100 by default.
If you need something else: `cp docker-compose.override.yml.example docker-compose.override.yml` and set it up.

## Configuration

You should need to do this only once...

1. Check that your VPN is working and you can access the reference server.
1. Set the correct SSH hostname in [inventory/production.yml](https://github.com/openSUSE/ansible-obs/blob/master/inventory/production.yml).
1. Set the correct credentials and information regarding the GitHub Deployments in .env

    ```shell
    cp .env.template .env
    vi .env
    ```

## Usage

1. Run the container (this opens a shell):

    ```shell
    docker-compose run --rm ansible-obs
    ```

1. Check the diff of the changes you are going to introduce

    ```shell
    bin/obs_deploy check-diff
    ```

1. Check if there is a `monkey patch` in the server and act accordingly. Check the content of `/etc/motd`.
1. Deploy using the correct playbook, they are described below.

    ```shell
    ansible-playbook -i inventory/production.yml $playbook
    ```

1. Or check out the other things you can do with `obs_deploy` and `ogd`

    ```shell
    bin/obs_deploy -h
    ...
    bin/ogd --help
    ```

## Playbooks

Depending on what you deploy, we have some different playbooks...

### Deployment without migration

Most of our deployments only contain code changes that don't introduce any changes on the database schema, data or require downtime for any other reasons.

```shell
ansible-playbook -i inventory/production.yml deploy_without_migration.yml
```

If we detect that there is any schema or data migration in the deployment, this will abort. If that is the case, check the other options below.

### Deployment with migration online

Many database/data migrations are non-disruptive and therefore don't cause downtimes. This playbook will **not** put
the OBS into maintenance mode and apply the migrations online.

⚠️ Note: You need to check upfront if the database/data migration is a non-disruptive one, the playbook is not able to distinguish between those two cases. Once you've confirmed that there won't be downtime needed, go ahead. Otherwise, see the other option below.

```
ansible-playbook -i inventory/production.yml deploy_with_migration_without_downtime.yml
```

### Deployment with migration with downtime

In many cases, database migrations require to stop all interactions of the application with the database while they are getting executed. Therefore causing downtime.

⚠️ NOTE: Database migrations with downtime should run in the maintenance window Thursday 8AM - 10AM CET/CEST

```
ansible-playbook -i inventory/production.yml deploy_with_migration.yml
```

## Troubleshooting

If shit has hit the fan, see our production page in the developer wiki

https://github.com/openSUSE/open-build-service/wiki/build.opensuse.org

### Local Files Changes

If there are changes to the `obs-api` package in the reference server, ansible-obs will let you know and will stop the deployment.
Handle the monkey-patch first, if any, or double-check with your colleagues.
Only when you are completely sure those changes can be overwritten,
you can run the playbook with the variable to skip the check. For example:

```shell
ansible-playbook -i inventory/production.yml deploy_without_migration.yml -e "skip_local_rpm_check=true"
```

### Track Deployments by Hand

If, for some reason, you couldn't use ansible-obs to deploy and had to do it manually, please track the deploy by hand, so it shows up [here](https://github.com/openSUSE/open-build-service/deployments/production). This is an example of how to do it:

```shell
bin/dotenv bin/ogd succeed --ref=<current version sha>
```
	
You can get the current version sha with:

```shell
bin/obs_deploy dv | cut -f2 -d':'
```

## Monkey-patching

As far as possible, when you find a bug, act as usual: create a Pull Request, wait for it to be reviewed and merged and then wait until the changes can be deployed.

If you can't wait that long (the bug is destroying data, blocking many users' work or even killing the whole application) then you might need to monkey-patch some fix:

1. Block the deployment until you have a proper fix
    ```shell
    ogd lock --reason "There is a monkey patch in app/blah/blubb.rb"
    ```
    Note: you can have ogd set up on your machine but it's also ready to be used inside the ansible-obs docker container.
1. Change the code on production (apply the patch)
1. Restart passenger `touch ~/api/tmp/restart.txt` to make the server run with the new code
1. Whatever you patched, open a draft PR with it and attach the monkey patch label
1. Point to the PR in `/etc/motd` on production
    ```shell
    APPLIED MONKEY PATCHES
    ----------------------

    Henne: https://github.com/openSUSE/open-build-service/pull/12798
    ```
1. Once the PR is merged, unblock the deployment
    ```shell
    ogd unlock
    ```
1. Remove things from `/etc/motd` on production

