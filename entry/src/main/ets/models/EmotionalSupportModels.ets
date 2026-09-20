export interface EmotionalSupportMessage {
  id: string;
  role: string;
  text: string;
  createdAt: number;
}

export interface EmotionalSupportRequest {
  message: string;
  history: EmotionalSupportMessage[];
}

export interface EmotionalSupportResponse {
  ok: boolean;
  reply?: string;
  crisis?: boolean;
  source?: string;
  model?: string;
  error?: string;
}
