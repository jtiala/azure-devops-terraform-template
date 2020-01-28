db.createUser({
  user: "api",
  pwd: "api",
  roles: [
    {
      role: "readWrite",
      db: "api"
    }
  ]
});
