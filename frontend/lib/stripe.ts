import { loadStripe } from "@stripe/stripe-js";

const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;

// Singleton — loadStripe caches the promise internally.
export const stripePromise = publishableKey ? loadStripe(publishableKey) : null;
