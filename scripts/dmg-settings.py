"""Repeatable two-icon Finder layout for Storage Lens — By Eridyn."""
from pathlib import Path
root = Path(defines['project']).resolve()
format = 'UDZO'
filesystem = 'HFS+'
files = [str(root / 'build/Storage Lens.app')]
symlinks = {'Applications': '/Applications'}
icon = str(root / 'Resources/AppIcon.icns')
background = str(root / 'build/dmg-background.tiff')
window_rect = ((240, 180), (720, 450))
default_view = 'icon-view'
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
icon_size = 128
text_size = 14
label_pos = 'bottom'
icon_locations = {'Storage Lens.app': (190, 220), 'Applications': (530, 220)}
hide_extensions = ['Storage Lens.app']
show_icon_preview = False
