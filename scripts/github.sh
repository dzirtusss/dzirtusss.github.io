curl -H 'Authorization: token XXX' -X PUT https://api.github.com/repos/dzirtusss/dzirtusss.github.io/contents/test1 -d '
{
  "message": "test",
  "committer": {
    "name": "Serg",
    "email": "dzirtusss@gmail.com"
  },
  "content": "bXkgbmV3IGZpbGUgY29udGVudHM="
}
'
