#!/usr/bin/python3
"""Aggregate release from release project"""

import logging
from pathlib import Path
import osc.core
import shared
from CosuMiniSettings import CosuMiniSettings
from xml.etree import ElementTree
parser = shared.SharedArgParse(
    prog =  Path(__file__).name,
    description = 'Aggregate release from release project')


# load updater config?
# verify config?

parser.add_argument('-C', '--release-configuration-project', dest = "rel_conf_prj",
                    required= True,
                    help="Extra project that contains the release packages")
parser.add_argument('-R', '--release-project', dest='rel_prj',
                    required= True,
                    help="Release project to target")
parser.add_argument('-s', '--settings-path', dest = 'settings_paths',
                    required = True,
                    help="Path to release configuration, can supplied more than once")

args = parser.parse_args()

env = shared.ParseEnvfile()

# shared?
apiurl = env['apiurl']

if args.apiurl:
    apiurl = args.apiurl

config = shared.GetConfig({"override_apiurl": apiurl})
# shared
# FIXME check how to pass these to osc
#config["debug"] = True
#config["http_full_debug"] = True


settings = CosuMiniSettings(args.settings_paths)

aggregate_package_name = "osupdate-package-pattern"
aggregate_package_section = "adaptation"
if not aggregate_package_name in settings[aggregate_package_section]:
    logging.error("Aggregate Package name {aggregate_package_name} not defined" ,
                  aggregate_package_name=aggregate_package_name)
    raise ValueError
meta = shared.PrjConf(path_args=args.rel_prj, apiurl=apiurl)

supported_devices = meta["Macros"]["supported_devices"].removesuffix('"')
supported_devices = supported_devices.removeprefix('"').split(' ')

device_repository = osc.core.get_repositories_of_project(apiurl, args.rel_prj)

for device in supported_devices:
    settings.set("adaptation", "deviceModel", device)
    aggregate_package = settings.variable("adaptation", "%(osupdate-package-pattern)")
    bi_text = osc.core.decode_it(osc.core.get_buildinfo(apiurl = apiurl,
                      prj = args.rel_prj,
                      package = aggregate_package,
                      repository = device_repository[0],
                      arch = meta["Macros"]["device_rpm_architecture_string"][0]
                  ))
    xmlRoot = ElementTree.fromstring(bi_text)
    ver = xmlRoot.findall("versrel")[0].text.split('-')[0]
    osc.core.aggregate_pac(src_project = args.rel_prj,
                           src_package = aggregate_package,
                           dst_project = args.rel_conf_prj,
                           dst_package = f"{aggregate_package}-{ver}",
                           nosources = True)
