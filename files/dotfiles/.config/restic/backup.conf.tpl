BACKUP_INCLUDES="--files-from=/home/pietro/.config/restic/restic-includes"
BACKUP_EXCLUDES="--exclude-file=/home/pietro/.config/restic/restic-excludes --exclude-if-present=.exclude-from-backup"
RETENTION_DAYS=7
RETENTION_WEEKS=4
RETENTION_MONTHS=6
RETENTION_YEARS=3

RESTIC_REPOSITORY="s3:https://s3.amazonaws.com/YOURBUCKET"                                
AWS_ACCESS_KEY_ID=XXXXXXXX
AWS_SECRET_ACCESS_KEY=YYYYYYYYYYYYYYYYYY
RESTIC_PASSWORD=ZZZZZZZZZZZZZZZZZZ
