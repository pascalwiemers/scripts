# Sync to remote machine's blender config
rsync -avz "$HOME/.config/blender/" "node@192.168.8.134:~/.config/blender"

# Sync to blender config on the remote machine (specified user)
rsync -avz "$HOME/.config/blender/" "node@192.168.8.134:~/.config/blender"
