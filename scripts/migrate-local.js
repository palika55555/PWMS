import { getLocalDb } from '../config/database.js';
import { createLocalSchema } from '../models/database-schema.js';

const db = getLocalDb();
createLocalSchema(db);
console.log('Local database schema created/updated successfully');
db.close();

