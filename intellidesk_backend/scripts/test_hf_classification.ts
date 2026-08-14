import { classifyCategoryDynamic } from '../src/utils/categoryClassifier.js';

async function runTest() {
  const query = "I had input a query of medical bills for cancer treatment at the university hospital.";
  console.log(`\n🧪 Testing Hugging Face Zero-Shot Transformer Model Classification on query:\n"${query}"\n`);
  
  const category = await classifyCategoryDynamic(query);
  console.log(`\n🎉 Final Classification Output: "${category}"\n`);
}

runTest().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
