const axios = require('axios');

test('Retrieve last entry', async () => {
  const response = await axios.get('http://localhost:3000/last-entry');
  expect(response.status).toBe(200);
});

test('Add new entry', async () => {
  const response = await axios.post('http://localhost:3000/add-entry');
  expect(response.status).toBe(200);
});
