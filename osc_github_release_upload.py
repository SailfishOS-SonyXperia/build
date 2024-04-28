#!/usr/bin/python3
"""Upload release images previously built from a device project to the Github release"""

from pathlib import Path
import github_release

import shared

parser = shared.SharedArgParse(
    prog =  Path(__file__).name,
    description = 'Aggregate release from release project')
parser.add_argument('-R', '--github-release', dest='github_release',
                    required=True,
                    help="Github release to upload our assets too")
parser.add_argument('-r', '--repo-name',  dest='repo_name',
                    required=True,
                    help="Target repository to upload too")
parser.add_argument('-D', '--release-project', dest='rel_prj',
                    required= True,
                    help="Release project to target")

args = parser.parse_args()


env = shared.ParseEnvfile()

# shared?
apiurl = env['apiurl']

if args.apiurl:
    apiurl = args.apiurl

config = shared.GetConfig({"override_apiurl": apiurl})

meta = shared.PrjConf(path_args=args.rel_prj, apiurl=apiurl)
supported_devices = meta["Macros"]["supported_devices"].removesuffix('"')
supported_devices = supported_devices.removeprefix('"').split(' ')


base_path_pattern = "SailfishOS-release-"

# Strip suffix from sailfish os version that the release
# is named after.
sailfishos_version=args.github_release.split(sep="+")[0]

for device in supported_devices:
    # github_release uses string globbing here path functions won't work
    github_release.gh_asset_upload(repo_name=args.repo_name,
                                   tag_name=args.github_release,
                                   pattern=base_path_pattern+sailfishos_version+"-"+device+"/*.zip")
