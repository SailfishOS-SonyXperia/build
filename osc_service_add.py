#!/usr/bin/env python


from xml.etree import ElementTree
from pathlib import Path
import argparse

opt_tar_git = True
opt_webhook = True


parser = argparse.ArgumentParser(
    prog = 'osc_service_add',
    description = 'Create osc _service for tar_git and webhook',
    epilog = '')

parser.add_argument('service_file')
parser.add_argument('-w', '--webhook', dest = 'webhook', action="store_true",
                    help = "Create Webhook service")
parser.add_argument('-P', '--project', dest = 'obs_project',
                    required = True,
                    help = "OBS Project to upload to")
parser.add_argument('-p', '--package', dest = 'obs_package',
                    required = True,
                    help = "OBS Package to create")
parser.add_argument('-r', '--repository', dest = 'repository',
                    required = True,
                    help = "repository url")
parser.add_argument('-b', '--branch', dest = 'branch',
                    default = 'master',
                    help = "Target branch (default: master)")

args = parser.parse_args()

service = Path(args.service_file)

services = ElementTree.Element("services")
xmlFile = ElementTree.ElementTree(element=services)

if args.webhook:
    webhook = ElementTree.SubElement(services, "service", name="webhook")
    webhook_params = dict()
    webhook_params['repourl'] = ElementTree.SubElement(webhook, "param",
                                                       name = "repo_url")
    webhook_params['repourl'].text = args.repository
    webhook_params['branch'] = ElementTree.SubElement(webhook, "param",
                                                      name = "branch")
    webhook_params['branch'].text = args.branch


tar_git = ElementTree.SubElement(services, "service", name="tar_git")
tar_git_params = dict()
tar_git_params['url'] = ElementTree.SubElement(tar_git, "param",
                                               name = "url")
tar_git_params['url'].text = args.repository

tar_git_params['branch'] = ElementTree.SubElement(tar_git, "param",
                                                  name = "branch")
tar_git_params['branch'].text = args.branch

tar_git_params['dumb'] = ElementTree.SubElement(tar_git, "param",
                                                name = "dumb")
tar_git_params['dumb'].text = "N"


ElementTree.indent(xmlFile)
xmlFile.write(service)
