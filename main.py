from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from uuid import uuid4

app = FastAPI()

# In-memory storage (resets every time you restart)
items_by_id = {}


class ItemCreate(BaseModel):
    name: str
    price: float


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/items", status_code=201)
def create_item(item: ItemCreate):
    # prevent duplicates by name (simple rule)
    for existing in items_by_id.values():
        if existing["name"].lower() == item.name.lower():
            raise HTTPException(status_code=400, detail="Item already exists")

    item_id = str(uuid4())
    new_item = {"id": item_id, "name": item.name, "price": item.price}
    items_by_id[item_id] = new_item
    return new_item


@app.get("/items/{item_id}")
def get_item(item_id: str):
    if item_id not in items_by_id:
        raise HTTPException(status_code=404, detail="Not found")
    return items_by_id[item_id]


@app.delete("/items/{item_id}", status_code=204)
def delete_item(item_id: str):
    if item_id not in items_by_id:
        raise HTTPException(status_code=404, detail="Not found")
    del items_by_id[item_id]
    return None
