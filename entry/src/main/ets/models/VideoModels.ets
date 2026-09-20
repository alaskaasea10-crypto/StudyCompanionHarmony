export interface LearningVideo {
  id: string;
  moduleId: string;
  title: string;
  topic: string;
  platform: string;
  publisher: string;
  url: string;
  publishedAt: string;
  format: string;
  description: string;
  note: string;
}

export interface VideoModule {
  id: string;
  title: string;
  subtitle: string;
  accent: string;
  tint: string;
  searchTerm: string;
}

export interface VideoLibraryState {
  favoriteIds: string[];
  watchedIds: string[];
}
