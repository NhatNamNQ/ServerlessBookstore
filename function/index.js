const sharp = require("sharp");
const {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
} = require("@aws-sdk/client-s3");
const { Buffer } = require("node:buffer");

const client = new S3Client({ region: process.env.REGION });

const width = parseInt(process.env.WIDTH);
const height = parseInt(process.env.HEIGHT);
const destinationBucket = process.env.DES_BUCKET;

const streamToBuffer = async (stream) => {
  return await new Promise((resolve, reject) => {
    const chunks = [];

    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks)));
  });
};

exports.handler = async function (event, context) {
  if (event.Records[0].eventName === "ObjectRemove:Delete") {
    return;
  }

  const BUCKET = event.Records[0].s3.bucket.name;
  const KEY = event.Records[0].s3.object.key;

  try {
    // Get uploaded image
    let image = await client.send(
      new GetObjectCommand({ Bucket: BUCKET, Key: KEY }),
    );
    image = await streamToBuffer(image.Body);

    // Resize image
    let resizedImage = await sharp(image)
      .resize(width, height, { fit: "fill", withoutEnlargement: true })
      .toBuffer();

    // Upload resized image to resized bucket
    await client.send(
      new PutObjectCommand({
        Bucket: destinationBucket,
        Body: resizedImage,
        Key: KEY,
      }),
    );

    // Delete original image
    await client.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: KEY }));

    return;
  } catch (err) {
    context.fail(`Error resizing image: ${err} `);
  }
};
