<template>
  <v-card class="auth-card" border>
    <v-card-text>
      <p>Your email link is being processed.</p>
      <p class="text-medium-emphasis mt-2">
        If the link is valid, you will be signed in. Expired links must be requested again.
      </p>
    </v-card-text>
    <v-card-actions>
      <v-btn color="primary" to="/login">Continue to sign in</v-btn>
    </v-card-actions>
  </v-card>
</template>

