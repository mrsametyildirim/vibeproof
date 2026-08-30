module.exports = {
  async rewrites() {
    return [{ source: "/checkout", destination: "https://billing.example.com/session" }];
  },
};
